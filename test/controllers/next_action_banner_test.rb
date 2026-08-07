# frozen_string_literal: true

require "test_helper"

class NextActionBannerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
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

    assert_select ".lp-dash-next[data-next-action-key=plan_route]", count: 1
    assert_select ".lp-dash-next__title", text: I18n.t("strategy.next_action.plan_route.title")
    assert_select "a.lp-cta", text: I18n.t("strategy.next_action.plan_route.cta")
  end

  test "set_today banner when spine exists without daily todos" do
    build_spine_without_cascade!

    get dashboard_path
    assert_response :success

    assert_select ".lp-dash-next[data-next-action-key=set_today]", count: 1
    assert_select ".lp-dash-next__title", text: I18n.t("strategy.next_action.set_today.title")
    assert_select "a.lp-cta", text: I18n.t("strategy.next_action.set_today.cta")
  end

  test "complete_battle banner includes todo title" do
    build_spine_and_cascade!(title: "Send five emails")

    get dashboard_path
    assert_response :success

    assert_select ".lp-dash-next[data-next-action-key=complete_battle]", count: 1
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

    assert_select ".lp-dash-next[data-next-action-key=confirm_camp]", count: 1
    # Queue stores the practice parent (leaf camp) after a real complete.
    assert_select ".lp-dash-next__title"
    assert_select "a.lp-cta", text: I18n.t("strategy.next_action.confirm_camp.cta")
    assert_match(/Check camp/i, css_select(".lp-dash-next__title").text)
  end

  test "day_won banner when todos are done and no camp confirmation pending" do
    build_spine_and_cascade!(title: "Send five emails")
    complete_all_todos!

    get dashboard_path
    assert_response :success

    assert_select ".lp-dash-next[data-next-action-key=day_won]", count: 1
    assert_select ".lp-dash-next__title", text: I18n.t("strategy.next_action.day_won.title")
    assert_select "a.lp-cta", text: I18n.t("strategy.next_action.day_won.cta")
  end

  test "banner absent when journey has no goal" do
    @goal.destroy!

    get dashboard_path
    assert_response :success

    assert_select ".lp-dash-next", count: 0
  end

  private

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
