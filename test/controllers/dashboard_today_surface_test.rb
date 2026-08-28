# frozen_string_literal: true

require "test_helper"

# Guards the shared TodaySurface loader — non-gap Today must keep loading.
class DashboardTodaySurfaceTest < ActionDispatch::IntegrationTest
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
    # Easy commitment → no commitment_gap short-circuit.
    @journey.update!(
      commitment_key: "easy",
      commitment_name: "Easy",
      commitment_habit_count: 1,
      commitment_battle_count: 1
    )
    @user.habits.active.on_home.destroy_all
    @user.habits.create!(name: "Water", active: true, show_on_home: true, unit: "times")
  end

  test "non-gap Today loads battle surface wrapper without error" do
    get dashboard_path
    assert_response :success
    assert_select "#today-battle-surface"
    assert_select "#next-action-slot"
    assert_select "[data-next-action-key=commitment_gap]", count: 0
    assert_select ".lp-dash-header, .lp-dash", minimum: 1
  end

  test "Easy with zero habits shows setup_gap not commitment_gap" do
    enable_habits!
    @user.habits.active.on_home.destroy_all
    @user.daily_todos.create!(
      title: "First fight", scheduled_on: Date.current, aspect_key: "career",
      position: 1
    )

    get dashboard_path
    assert_response :success
    assert_select "[data-next-action-key=commitment_gap]", count: 0
    assert_select "#commitment-gap-panel[data-next-action-key=setup_gap]", count: 1
  end

  test "dashboard sync surfaces future one-shot battles on today" do
    journey = seed_climb!(@user, today_mission: "Existing fight")
    goal = @user.strategy_goals.for_kind("goal").roots.first
    plan = goal.children.find(&:plan?)
    camp = plan.children.find(&:project?)
    camp.children.create!(
      user: @user, life_area: journey.life_area, life_journey: journey,
      horizon: "day", title: "Milestone fight", scheduled_on: 1.month.from_now.to_date,
      repeat: "none", position: 99
    )

    get dashboard_path
    assert_response :success
    assert @user.daily_todos.for_day.exists?(title: "Milestone fight")
  end

  test "dashboard shows waiting indicator when cap hides battles" do
    journey = seed_climb!(@user, today_mission: "Existing fight")
    goal = @user.strategy_goals.for_kind("goal").roots.first
    plan = goal.children.find(&:plan?)
    camp = plan.children.find(&:project?)
    24.times do |i|
      camp.children.create!(
        user: @user, life_area: journey.life_area, life_journey: journey,
        horizon: "day", title: "Overflow #{i}", scheduled_on: 1.month.from_now.to_date,
        repeat: "none", position: 100 + i
      )
    end

    get dashboard_path
    assert_response :success
    assert_select "#today-battles-waiting", text: /5 more battles on Mountain/
  end

  test "completing at open cap surfaces next waiting battle on dashboard sync" do
    journey = seed_climb!(@user, today_mission: "Existing fight")
    goal = @user.strategy_goals.for_kind("goal").roots.first
    plan = goal.children.find(&:plan?)
    camp = plan.children.find(&:project?)
    24.times do |i|
      camp.children.create!(
        user: @user, life_area: journey.life_area, life_journey: journey,
        horizon: "day", title: "Overflow #{i}", scheduled_on: 1.month.from_now.to_date,
        repeat: "none", position: 100 + i
      )
    end

    get dashboard_path
    assert_response :success
    assert_equal GameRules::MAX_DAILY_TODOS, GameRules.daily_open_count(@user, Date.current)
    assert_equal 5, Today::BattlesWaiting.count(user: @user, life_area: journey.life_area)

    todo = @user.daily_todos.for_day.incomplete.ordered.first
    post complete_daily_todo_path(todo), as: :turbo_stream
    assert_response :ok

    assert todo.reload.completed?
    assert_equal GameRules::MAX_DAILY_TODOS, GameRules.daily_open_count(@user, Date.current)
    assert_equal 4, Today::BattlesWaiting.count(user: @user, life_area: journey.life_area)
    assert_operator @user.daily_todos.for_day.count, :>, GameRules::MAX_DAILY_TODOS
  end
end
