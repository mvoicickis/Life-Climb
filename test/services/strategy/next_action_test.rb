# frozen_string_literal: true

require "test_helper"

class Strategy::NextActionTest < ActiveSupport::TestCase
  include ClimbTestHelper

  setup do
    @user = users(:one)
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
    # Keep legacy chain tests before the overdue hour gate.
    travel_to Time.zone.local(Date.current.year, Date.current.month, Date.current.day, 10, 0, 0)
  end

  teardown do
    travel_back
  end

  test "returns nil without a journey" do
    @user.life_journeys.update_all(status: "completed", focus_position: nil)
    @user.reload
    assert_nil @user.primary_focused_journey
    assert_nil Strategy::NextAction.for(user: @user)
  end

  test "returns nil when journey has no goal" do
    @goal.destroy!
    assert_nil Strategy::NextAction.for(user: @user, journey: @journey)
  end

  test "plan_route when goal has no plan children" do
    result = Strategy::NextAction.for(user: @user, journey: @journey)

    assert_equal :plan_route, result.key
    assert_equal :steady, result.tone
    assert_equal 0, result.urgency
    assert_equal I18n.t("strategy.next_action.plan_route.title"), result.title
    assert_equal I18n.t("strategy.next_action.plan_route.cta"), result.cta_label
    assert_includes result.href, "/life_journeys/#{@journey.id}"
  end

  test "set_today when plans exist but no daily_todos for today" do
    build_spine_without_cascade!

    result = Strategy::NextAction.for(user: @user, journey: @journey)

    assert_equal :set_today, result.key
    assert_equal :steady, result.tone
    assert_equal I18n.t("strategy.next_action.set_today.title"), result.title
    assert_equal "/dashboard", result.href
  end

  test "complete_battle when an incomplete daily_todo exists for today before overdue hour" do
    build_spine_and_cascade!(title: "Send five emails")

    result = Strategy::NextAction.for(user: @user, journey: @journey)

    assert_equal :complete_battle, result.key
    assert_equal :steady, result.tone
    assert_equal 0, result.urgency
    assert_equal "Send five emails", result.todo_title
    assert_includes result.title, "Send five emails"
    assert_equal I18n.t("strategy.next_action.complete_battle.cta"), result.cta_label
    assert_equal "/dashboard", result.href
  end

  test "battle_overdue wins after overdue hour with open todos" do
    build_spine_and_cascade!(title: "Send five emails")
    travel_to Time.zone.local(Date.current.year, Date.current.month, Date.current.day, 19, 0, 0)

    result = Strategy::NextAction.for(user: @user, journey: @journey)

    assert_equal :battle_overdue, result.key
    assert_equal :urgent, result.tone
    assert_equal 100, result.urgency
    assert_equal "Send five emails", result.todo_title
  end

  test "streak_at_risk when climb was yesterday and nothing completed today" do
    build_spine_and_cascade!(title: "Send five emails")
    @user.update!(climb_streak_days: 5, climb_streak_on: Date.current - 1)

    result = Strategy::NextAction.for(user: @user, journey: @journey)

    assert_equal :streak_at_risk, result.key
    assert_equal :urgent, result.tone
    assert_equal 90, result.urgency
    assert_equal 5, result.streak_days
  end

  test "battle_overdue beats streak_at_risk after overdue hour" do
    build_spine_and_cascade!(title: "Send five emails")
    @user.update!(climb_streak_days: 5, climb_streak_on: Date.current - 1)
    travel_to Time.zone.local(Date.current.year, Date.current.month, Date.current.day, 20, 0, 0)

    result = Strategy::NextAction.for(user: @user, journey: @journey)

    assert_equal :battle_overdue, result.key
    assert_equal 100, result.urgency
  end

  test "project_unlocked when previous sibling completed recently" do
    @user.update!(climb_streak_days: 0, climb_streak_on: nil)
    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @goal, horizon: "plan",
      title: "Get interviews", position: 0
    )
    first = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project",
      title: "Polish resume", position: 0, completed_at: 1.day.ago
    )
    second = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project",
      title: "Improve apps", position: 1
    )
    assert first.completed?
    refute second.completed?

    result = Strategy::NextAction.for(user: @user, journey: @journey)

    assert_equal :project_unlocked, result.key
    assert_equal :discovery, result.tone
    assert_equal 80, result.urgency
    assert_equal "Improve apps", result.project_title
  end

  test "quest_stalled when open quest has been quiet for stall days" do
    @user.update!(climb_streak_days: 0, climb_streak_on: nil)
    build_spine_and_cascade!(title: "Checklist quest")
    todo = @user.daily_todos.for_day(Date.current).find_by!(title: "Checklist quest")
    day = todo.strategy_goal
    task = day.practice_tasks.create!(user: @user, title: "Write outline", position: 0)
    quiet = (Strategy::NextAction::QUEST_STALL_DAYS + 1).days.ago
    day.update_columns(updated_at: quiet)
    task.update_columns(updated_at: quiet)

    result = Strategy::NextAction.for(user: @user, journey: @journey)

    assert_equal :quest_stalled, result.key
    assert_equal :discovery, result.tone
    assert_equal 60, result.urgency
    assert_equal "Checklist quest", result.todo_title
  end

  test "confirm_camp when todos are done and ProjectCheckQueue has a pending project" do
    project = build_spine_and_cascade!(title: "Send five emails")
    complete_all_todos!

    session = {}
    Strategy::ProjectCheckQueue.enqueue(session: session, project_ids: [ project.id ])

    result = Strategy::NextAction.for(user: @user, journey: @journey, session: session)

    assert_equal :confirm_camp, result.key
    assert_equal :steady, result.tone
    assert_equal project.title, result.project_title
    assert_includes result.title, project.title
    assert_equal "/dashboard", result.href
  end

  test "day_won when todos are done and no pending camp confirmation" do
    build_spine_and_cascade!(title: "Send five emails")
    complete_all_todos!

    result = Strategy::NextAction.for(user: @user, journey: @journey, session: {})

    assert_equal :day_won, result.key
    assert_equal :steady, result.tone
    assert_equal I18n.t("strategy.next_action.day_won.title"), result.title
    assert_includes result.href, "/life_journeys/#{@journey.id}"
  end

  test "day_won when todos are done and session is nil" do
    project = build_spine_and_cascade!(title: "Send five emails")
    complete_all_todos!
    # Without session, ProjectCheckQueue cannot surface — fall through to day_won.
    session = {}
    Strategy::ProjectCheckQueue.enqueue(session: session, project_ids: [ project.id ])

    result = Strategy::NextAction.for(user: @user, journey: @journey, session: nil)

    assert_equal :day_won, result.key
    assert_equal :steady, result.tone
  end

  # Follow-up note: Mountain may still show a strategy day with scheduled_on == today
  # while DailyTodo is empty (CascadeToDaily not run). Resolver trusts DailyTodo.
  test "disagreement note: strategy day without cascaded todo yields set_today" do
    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @goal, horizon: "plan",
      title: "Get interviews", position: 0
    )
    project = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project",
      title: "Improve apps", position: 0
    )
    leaf = practice_leaf_for!(project)
    day = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: leaf, horizon: "day",
      title: "Only on the mountain spine", scheduled_on: Date.current, position: 0
    )

    refute @user.daily_todos.for_day(Date.current).exists?,
           "precondition: no cascaded DailyTodo for the strategy day"
    assert_equal Date.current, day.scheduled_on

    result = Strategy::NextAction.for(user: @user, journey: @journey)

    assert_equal :set_today, result.key,
                 "DailyTodo is authority; unsynced strategy day must not become complete_battle"
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
