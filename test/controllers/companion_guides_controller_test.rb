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

  test "settings does not include temporary companion guide link" do
    get settings_path
    assert_response :success
    assert_select "a[href=?]", companion_guide_path, count: 0
    assert_select "a[href=?]", companion_guide_path(new_plan: 1), count: 0
  end

  test "mountain + Path links to companion guide with new_plan" do
    get life_journey_path(@journey)
    assert_response :success
    assert_select "a.lp-rpg-add.is-path.is-guide-entry[href=?]", companion_guide_path(new_plan: 1)
  end

  test "new_plan after completed restarts guide without touching prior plans" do
    walk_to_completed!
    plan_count = @goal.children.for_kind("plan").count
    project_count = @user.strategy_goals.for_kind("project").count
    prior_plan_ids = @goal.children.for_kind("plan").pluck(:id).sort

    get companion_guide_path(new_plan: 1)
    assert_response :success
    assert_select "#companion-guide-question", text: I18n.t("strategy.companion_guide.questions.create_plan")

    cursor = Strategy::CompanionGuide::Cursor.load(@journey.reload)
    assert_equal "in_progress", cursor["status"]
    assert_equal "create_plan", cursor["template_id"]
    assert_nil cursor["plan_id"]

    assert_equal plan_count, @goal.children.for_kind("plan").count
    assert_equal project_count, @user.strategy_goals.for_kind("project").count
    assert_equal prior_plan_ids, @goal.children.for_kind("plan").pluck(:id).sort
  end

  test "new_plan while in_progress does not reset the guide" do
    post companion_guide_path, params: { value: "Land interviews" }
    follow_redirect!
    assert_select "#companion-guide-question", text: I18n.t("strategy.companion_guide.questions.set_effort_tier")

    plan = @goal.children.for_kind("plan").ordered.last
    cursor_before = Strategy::CompanionGuide::Cursor.load(@journey.reload)

    get companion_guide_path(new_plan: 1)
    assert_response :success
    assert_select "#companion-guide-question", text: I18n.t("strategy.companion_guide.questions.set_effort_tier")

    cursor_after = Strategy::CompanionGuide::Cursor.load(@journey.reload)
    assert_equal cursor_before, cursor_after
    assert_equal plan.id, cursor_after["plan_id"]
    assert_equal "set_effort_tier", cursor_after["template_id"]
  end

  test "blank title re-renders same step with preserved value and specific error" do
    get companion_guide_path
    assert_response :success

    assert_no_difference -> { @goal.children.for_kind("plan").count } do
      post companion_guide_path, params: { value: "   " }
    end

    assert_response :unprocessable_entity
    assert_select "#companion-guide-question", text: I18n.t("strategy.companion_guide.questions.create_plan")
    assert_select "[data-companion-guide-error]", text: I18n.t("strategy.companion_guide.errors.blank_title")
    assert_select "input[name=value][value=?]", "   "
    assert_nil flash[:alert]
  end

  test "invalid tier re-renders with specific error and does not change plan" do
    post companion_guide_path, params: { value: "Land interviews" }
    follow_redirect!

    plan = @goal.children.for_kind("plan").ordered.last
    assert_nil plan.effort_tier

    post companion_guide_path, params: { value: "extreme" }
    assert_response :unprocessable_entity
    assert_select "#companion-guide-question", text: I18n.t("strategy.companion_guide.questions.set_effort_tier")
    assert_select "[data-companion-guide-error]", text: I18n.t("strategy.companion_guide.errors.bad_effort_tier")
    assert_nil plan.reload.effort_tier
  end

  test "invalid decision re-renders with specific error" do
    post companion_guide_path, params: { value: "Land interviews" }
    follow_redirect!
    post companion_guide_path, params: { value: "steady" }
    follow_redirect!
    post companion_guide_path, params: { value: "Polish resume" }
    follow_redirect!
    post companion_guide_path, params: { value: "Rewrite summary" }
    follow_redirect!

    post companion_guide_path, params: { value: "maybe" }
    assert_response :unprocessable_entity
    assert_select "#companion-guide-question", text: I18n.t("strategy.companion_guide.questions.continue_step")
    assert_select "[data-companion-guide-error]", text: I18n.t("strategy.companion_guide.errors.bad_decision")
  end

  test "mid-flow project deletion heals on show and can continue" do
    post companion_guide_path, params: { value: "Land interviews" }
    follow_redirect!
    post companion_guide_path, params: { value: "steady" }
    follow_redirect!
    post companion_guide_path, params: { value: "Polish resume" }
    follow_redirect!
    post companion_guide_path, params: { value: "Rewrite summary" }
    follow_redirect!

    project = @goal.children.for_kind("plan").first.children.for_kind("project").first
    project.destroy!

    get companion_guide_path
    assert_response :success
    assert_select "#companion-guide-question", text: I18n.t("strategy.companion_guide.questions.create_project")
    assert_select "[data-companion-guide-notice]"

    post companion_guide_path, params: { value: "Fresh project" }
    assert_redirected_to companion_guide_path
    follow_redirect!
    assert_select "#companion-guide-question", text: I18n.t("strategy.companion_guide.questions.create_day")
    assert @goal.children.for_kind("plan").first.children.for_kind("project").exists?(title: "Fresh project")
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
