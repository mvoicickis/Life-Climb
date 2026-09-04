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
    clear_setup_gap!

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
    seed_today_habits!(@journey.commitment_habit_count)
    # Zero battles needed so setup_gap stays quiet and legacy set_today can fire.
    @journey.update!(commitment_battle_count: 0)

    result = Strategy::NextAction.for(user: @user, journey: @journey)

    assert_equal :set_today, result.key
    assert_equal :steady, result.tone
    assert_equal I18n.t("strategy.next_action.set_today.title"), result.title
    assert_equal "/dashboard", result.href
  end

  test "complete_battle when an incomplete daily_todo exists for today before overdue hour" do
    build_spine_and_cascade!(title: "Send five emails")
    clear_setup_gap!

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
    clear_setup_gap!
    travel_to Time.zone.local(Date.current.year, Date.current.month, Date.current.day, 19, 0, 0)

    result = Strategy::NextAction.for(user: @user, journey: @journey)

    assert_equal :battle_overdue, result.key
    assert_equal :urgent, result.tone
    assert_equal 100, result.urgency
    assert_equal "Send five emails", result.todo_title
  end

  test "streak_at_risk when climb was yesterday and nothing completed today" do
    build_spine_and_cascade!(title: "Send five emails")
    clear_setup_gap!
    @user.update!(climb_streak_days: 5, climb_streak_on: Date.current - 1)

    result = Strategy::NextAction.for(user: @user, journey: @journey)

    assert_equal :streak_at_risk, result.key
    assert_equal :urgent, result.tone
    assert_equal 90, result.urgency
    assert_equal 5, result.streak_days
  end

  test "battle_overdue beats streak_at_risk after overdue hour" do
    build_spine_and_cascade!(title: "Send five emails")
    clear_setup_gap!
    @user.update!(climb_streak_days: 5, climb_streak_on: Date.current - 1)
    travel_to Time.zone.local(Date.current.year, Date.current.month, Date.current.day, 20, 0, 0)

    result = Strategy::NextAction.for(user: @user, journey: @journey)

    assert_equal :battle_overdue, result.key
    assert_equal 100, result.urgency
  end

  test "commitment_gap fires for ineligible Medium when today setup is clear but camps short" do
    force_ineligible_medium_camps_only!

    result = Strategy::NextAction.for(user: @user, journey: @journey)

    assert_equal :commitment_gap, result.key
    assert_equal :stuck, result.tone
    assert_match(/Medium needs 3 planned camps/i, result.title)
    assert_no_match(/Today habits/i, result.title)
    assert result.drop_easy
    labels = Array(result.fix_links).map { |link| link[:label] }
    assert_includes labels, I18n.t("settings.commitment.eligibility.open_mountain")
  end

  test "commitment_gap never fires on Easy" do
    Today::Commitment.apply_preset!(@journey, "easy")
    build_spine_and_cascade!(title: "Send five emails")

    result = Strategy::NextAction.for(user: @user, journey: @journey)

    assert_not_equal :commitment_gap, result.key
  end

  test "commitment_gap fires for ineligible custom counts when setup is clear" do
    seed_today_habits!(4)
    4.times do |n|
      @user.daily_todos.create!(
        title: "Fight #{n}", scheduled_on: Date.current, aspect_key: "career",
        start_time: "09:00", end_time: "10:00", position: n + 1
      )
    end
    @journey.update!(
      commitment_key: "custom",
      commitment_name: "Beast Mode",
      commitment_habit_count: 4,
      commitment_battle_count: 4
    )

    result = Strategy::NextAction.for(user: @user, journey: @journey)

    assert_equal :commitment_gap, result.key
    assert_match(/Beast Mode needs 4 planned camps/i, result.title)
  end

  test "commitment_gap short-circuits above battle_overdue and streak_at_risk" do
    force_ineligible_medium_camps_only!
    build_spine_and_cascade!(title: "Send five emails")
    clear_setup_gap!
    @user.update!(climb_streak_days: 5, climb_streak_on: Date.current - 1)
    travel_to Time.zone.local(Date.current.year, Date.current.month, Date.current.day, 20, 0, 0)

    overdue = Strategy::NextAction.new(user: @user, journey: @journey).send(:signal_battle_overdue)
    streak = Strategy::NextAction.new(user: @user, journey: @journey).send(:signal_streak_at_risk)
    assert overdue, "precondition: battle_overdue would fire"
    assert streak, "precondition: streak_at_risk would fire"
    assert_nil Today::Commitment.setup_gap(user: @user, journey: @journey),
               "precondition: setup_gap must stay quiet so commitment_gap can win"

    result = Strategy::NextAction.for(user: @user, journey: @journey)

    assert_equal :commitment_gap, result.key
    assert_equal :stuck, result.tone
  end

  test "setup_gap fires for Easy with zero habits and one untimed battle" do
    enable_habits!
    Today::Commitment.apply_preset!(@journey, "easy")
    @user.habits.active.on_home.destroy_all
    @user.daily_todos.create!(
      title: "First fight", scheduled_on: Date.current, aspect_key: "career",
      position: 1
    )

    result = Strategy::NextAction.for(user: @user, journey: @journey)

    assert_equal :setup_gap, result.key
    assert_equal :stuck, result.tone
    assert_equal :habits, result.setup_gap.kind
    assert_not result.drop_easy
  end

  test "setup_gap set_time when habit exists and battle is untimed" do
    Today::Commitment.apply_preset!(@journey, "easy")
    seed_today_habits!(1)
    todo = @user.daily_todos.create!(
      title: "Untimed fight", scheduled_on: Date.current, aspect_key: "career",
      position: 1
    )

    result = Strategy::NextAction.for(user: @user, journey: @journey)

    assert_equal :setup_gap, result.key
    assert_equal :set_time, result.setup_gap.kind
    assert_equal todo.id, result.setup_gap.todo.id
  end

  test "fully set up Easy falls through to complete_battle" do
    Today::Commitment.apply_preset!(@journey, "easy")
    build_spine_and_cascade!(title: "Send five emails")
    clear_setup_gap!

    result = Strategy::NextAction.for(user: @user, journey: @journey)

    assert_equal :complete_battle, result.key
    assert_not_equal :setup_gap, result.key
    assert_not_equal :commitment_gap, result.key
  end

  test "setup_gap short-circuits above battle_overdue and streak_at_risk" do
    enable_habits!
    Today::Commitment.apply_preset!(@journey, "easy")
    @user.habits.active.on_home.destroy_all
    build_spine_and_cascade!(title: "Send five emails")
    @user.update!(climb_streak_days: 5, climb_streak_on: Date.current - 1)
    travel_to Time.zone.local(Date.current.year, Date.current.month, Date.current.day, 20, 0, 0)

    result = Strategy::NextAction.for(user: @user, journey: @journey)

    assert_equal :setup_gap, result.key
    assert_equal :habits, result.setup_gap.kind
  end

  test "setup_gap short-circuits above commitment_gap when Medium lacks habits" do
    enable_habits!
    @user.habits.active.on_home.destroy_all
    @journey.update!(
      commitment_key: "medium",
      commitment_name: "Medium",
      commitment_habit_count: 3,
      commitment_battle_count: 3
    )

    result = Strategy::NextAction.for(user: @user, journey: @journey)

    assert_equal :setup_gap, result.key
    assert_equal :habits, result.setup_gap.kind
  end

  test "project_unlocked when previous sibling completed recently" do
    @user.update!(climb_streak_days: 0, climb_streak_on: nil)
    clear_setup_gap!
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
    clear_setup_gap!
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

  test "day_won when todos are done and no pending camp confirmation" do
    build_spine_and_cascade!(title: "Send five emails")
    clear_setup_gap!
    complete_all_todos!

    result = Strategy::NextAction.for(user: @user, journey: @journey, session: {})

    assert_equal :day_won, result.key
    assert_equal :steady, result.tone
    assert_equal I18n.t("strategy.next_action.day_won.title"), result.title
    assert_includes result.href, "/life_journeys/#{@journey.id}"
  end

  test "day_won when todos are done and session is nil" do
    build_spine_and_cascade!(title: "Send five emails")
    clear_setup_gap!
    complete_all_todos!

    result = Strategy::NextAction.for(user: @user, journey: @journey, session: nil)

    assert_equal :day_won, result.key
    assert_equal :steady, result.tone
  end

  # Follow-up note: Mountain may still show a strategy day with scheduled_on == today
  # while DailyTodo is empty (CascadeToDaily not run). Resolver trusts DailyTodo.
  test "disagreement note: strategy day without cascaded todo yields set_today" do
    seed_today_habits!(@journey.commitment_habit_count)
    @journey.update!(commitment_battle_count: 0)
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

  def clear_setup_gap!
    seed_today_habits!(@journey.commitment_habit_count)
    need = @journey.commitment_battle_count.to_i
    todos = @user.daily_todos.for_day(Date.current).ordered.to_a
    while todos.size < need
      todos << @user.daily_todos.create!(
        title: "Setup fight #{todos.size + 1}",
        scheduled_on: Date.current,
        aspect_key: "career",
        start_time: "09:00",
        end_time: "10:00",
        position: 500 + todos.size
      )
    end
    @user.daily_todos.for_day(Date.current).find_each do |todo|
      next if todo.timed?

      todo.update!(start_time: "09:00", end_time: "10:00")
    end
  end

  def seed_today_habits!(count)
    have = @user.habits.active.on_home.count
    (have + 1).upto(count) do |n|
      @user.habits.create!(
        name: "Habit #{n}", unit: "times", points: 5, frequency: "daily",
        active: true, show_on_home: true, quantity_checkin: false
      )
    end
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

  def force_ineligible_medium_camps_only!
    @journey.update!(
      commitment_key: "medium",
      commitment_name: "Medium",
      commitment_habit_count: 3,
      commitment_battle_count: 3
    )
    seed_today_habits!(3)
    3.times do |n|
      @user.daily_todos.create!(
        title: "Timed #{n}", scheduled_on: Date.current, aspect_key: "career",
        start_time: "09:00", end_time: "10:00", position: 50 + n
      )
    end
    elig = Today::Commitment.eligibility_for_counts(
      user: @user,
      journey: @journey,
      habit_count: 3,
      battle_count: 3,
      key: "medium"
    )
    assert_not elig.eligible?, "precondition: Medium must be structurally ineligible"
    assert elig.missing_camps
    assert_not elig.missing_habits
    assert_nil Today::Commitment.setup_gap(user: @user, journey: @journey)
  end
end
