# frozen_string_literal: true

require "test_helper"

class CompanionGuidesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(character: "fox")
    sign_in_as @user
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Find a job",
      ideal_scene: "Hired",
      current_reality: "Searching",
      today_mission: "Plan the path",
      closer_percent: 10,
      route_mission: true
    )
    @journey = @user.reload.primary_focused_journey
    @goal = @user.strategy_goals.for_kind("goal").roots.first
  end

  test "show renders the first create_plan question" do
    get companion_guide_path
    assert_response :success
    assert_select "#companion-guide-question", text: I18n.t("strategy.companion_guide.questions.create_plan")
    assert_select "input[name=value]"
    assert_select "form[action=?]", companion_guide_path
  end

  test "happy path posts through to completed with real records" do
    get companion_guide_path
    assert_response :success

    post companion_guide_path, params: { value: "Land interviews" }
    assert_redirected_to companion_guide_path
    follow_redirect!
    assert_select "[data-companion-guide-ack]"
    assert_match(/#{Regexp.escape(I18n.t('strategy.companion_guide.questions.set_effort_tier'))}/, response.body)

    post companion_guide_path, params: { value: "steady" }
    assert_redirected_to companion_guide_path
    follow_redirect!

    post companion_guide_path, params: { value: "Polish resume" }
    follow_redirect!

    post companion_guide_path, params: { value: "Rewrite summary" }
    follow_redirect!
    assert_match(/#{Regexp.escape(I18n.t('strategy.companion_guide.questions.continue_step'))}/, response.body)

    post companion_guide_path, params: { value: "advance" }
    follow_redirect!
    assert_match(/#{Regexp.escape(I18n.t('strategy.companion_guide.questions.continue_project'))}/, response.body)

    post companion_guide_path, params: { value: "advance" }
    assert_redirected_to companion_guide_path
    follow_redirect!

    assert_select "#companion-guide-done", text: I18n.t("strategy.companion_guide.shell.done_title")
    assert_select "a[href=?]", life_journey_path(@journey)

    plan = @goal.children.for_kind("plan").ordered.last
    assert_equal "Land interviews", plan.title
    assert_equal "steady", plan.effort_tier

    projects = plan.children.for_kind("project").ordered.to_a
    assert_equal 1, projects.size
    assert_equal "Polish resume", projects.first.title

    nested_ids = projects.first.children.for_kind("project").select(:id)
    days = StrategyGoal.where(parent_id: nested_ids, horizon: "day").ordered
    assert_equal [ "Rewrite summary" ], days.map(&:title)
  end

  test "completed show renders done screen" do
    walk_to_completed!

    get companion_guide_path
    assert_response :success
    assert_select "#companion-guide-done"
    assert_select "a.lp-cta[href=?]", life_journey_path(@journey)
  end

  test "show redirects safely without a focused journey" do
    @user.life_journeys.update_all(status: "completed", focus_position: nil)
    @user.reload

    get companion_guide_path
    assert_redirected_to dashboard_path
    assert_equal I18n.t("strategy.companion_guide.shell.need_journey"), flash[:alert]
  end

  test "settings includes temporary companion guide link" do
    get settings_path
    assert_response :success
    assert_select "a[href=?]", companion_guide_path
    assert_match I18n.t("strategy.companion_guide.shell.settings_link"), response.body
  end

  private

  def walk_to_completed!
    %w[
      Land\ interviews
      steady
      Polish\ resume
      Rewrite\ summary
      advance
      advance
    ].each do |value|
      post companion_guide_path, params: { value: value }
      assert_response :redirect
    end
  end
end
