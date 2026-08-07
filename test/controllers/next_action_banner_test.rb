# frozen_string_literal: true

require "test_helper"

class NextActionBannerTest < ActionDispatch::IntegrationTest
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
    @area = @journey.life_area
    @goal = @user.strategy_goals.for_kind("goal").roots.first
  end

  test "plan_route banner on Today when goal has no plans" do
    get dashboard_path
    assert_response :success

    assert_banner_state(:plan_route)
    assert_select "a.lp-cta", text: I18n.t("strategy.next_action.plan_route.cta")
  end

  test "set_today banner when spine exists without daily todos" do
    build_spine_without_cascade!

    get dashboard_path
    assert_response :success

    assert_banner_state(:set_today)
    assert_select "a.lp-cta", text: I18n.t("strategy.next_action.set_today.cta")
  end

  test "complete_battle banner includes todo title" do
    build_spine_and_cascade!(title: "Send five emails")

    get dashboard_path
    assert_response :success

    assert_banner_state(:complete_battle)
    assert_select ".lp-dash-next__title", text: /Send five emails/
    assert_select "a.lp-cta", text: I18n.t("strategy.next_action.complete_battle.cta")
  end

  test "confirm_camp banner when ProjectCheckQueue has a pending project" do
    build_spine_and_cascade!(title: "Send five emails")
    todo = @user.daily_todos.for_day(Date.current).find_by!(title: "Send five emails")

    post complete_daily_todo_path(todo)
    assert_redirected_to dashboard_path
    follow_redirect!
    assert_response :success

    assert_banner_state(:confirm_camp)
    assert_select "a.lp-cta", text: I18n.t("strategy.next_action.confirm_camp.cta")
  end

  test "day_won banner when todos are done and no camp confirmation pending" do
    build_spine_and_cascade!(title: "Send five emails")
    complete_all_todos!

    get dashboard_path
    assert_response :success

    assert_banner_state(:day_won)
    assert_select "a.lp-cta", text: I18n.t("strategy.next_action.day_won.cta")
  end

  test "banner absent when journey has no goal" do
    @goal.destroy!

    get dashboard_path
    assert_response :success

    assert_select ".lp-dash-next", count: 0
  end

  private

  def assert_banner_state(key)
    prefix = Strategy::NextAction::Copy::PREFIXES.fetch(key)
    assert_select ".lp-dash-next[data-next-action-key=#{key}]", count: 1
    title = css_select(".lp-dash-next__title").text
    assert title.start_with?(prefix.strip) || title.include?(prefix.strip),
           "expected #{prefix.inspect} in #{title.inspect}"
    assert_match(/🧭|📍|⚔️|🏕️|🏁/, title)
    assert_select ".lp-dash-next__face[src*='fox']", count: 1
  end

  def build_spine_without_cascade!
    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @goal, horizon: "plan",
      title: "Get interviews", position: 0
    )
    @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project",
      title: "Improve apps", position: 0
    )
  end

  def build_spine_and_cascade!(title:)
    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @goal, horizon: "plan",
      title: "Get interviews", position: 0
    )
    project = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project",
      title: "Improve apps", position: 0
    )
    leaf = practice_leaf_for!(project)
    @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: leaf, horizon: "day",
      title: title, scheduled_on: Date.current, position: 0
    )
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)
    project
  end

  def complete_all_todos!
    @user.daily_todos.for_day(Date.current).find_each do |todo|
      todo.update!(completed_at: Time.current)
    end
  end
end
