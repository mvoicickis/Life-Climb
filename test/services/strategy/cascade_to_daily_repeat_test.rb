# frozen_string_literal: true

require "test_helper"

class Strategy::CascadeToDailyRepeatTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @area = life_areas(:one_self)
    @goal = @user.strategy_goals.create!(life_area: @area, horizon: "goal", title: "Goal", position: 0)
    @plan = @user.strategy_goals.create!(
      life_area: @area, parent: @goal, horizon: "plan", title: "Plan", position: 0
    )
    @camp = @user.strategy_goals.create!(
      life_area: @area, parent: @plan, horizon: "project", title: "Camp", position: 0
    )
  end

  test "daily template gets a fresh todo after today is completed" do
    @camp_leaf = practice_leaf_for!(@camp)
    practice = @user.strategy_goals.create!(
      life_area: @area, parent: @camp_leaf, horizon: "day",
      title: "Do lessons", scheduled_on: Date.current, repeat: "daily", position: 0
    )

    Strategy::CascadeToDaily.call(
      user: @user, life_area: @area, from: Date.current, to: Date.current + 1.day
    )
    today_todo = @user.daily_todos.find_by!(strategy_goal_id: practice.id, scheduled_on: Date.current)
    assert_not today_todo.completed?

    today_todo.update!(completed_at: Time.current)
    practice.update!(scheduled_on: Date.current + 1.day, completed_at: nil)

    Strategy::CascadeToDaily.call(
      user: @user, life_area: @area, from: Date.current, to: Date.current + 1.day
    )
    tomorrow_todo = @user.daily_todos.find_by(strategy_goal_id: practice.id, scheduled_on: Date.current + 1.day)
    assert_not_nil tomorrow_todo
    assert_not tomorrow_todo.completed?
    assert practice.reload.repeat_daily?
    assert_nil practice.completed_at
  end

  test "one-shot with future scheduled_on surfaces on today" do
    @camp_leaf = practice_leaf_for!(@camp)
    battle = @user.strategy_goals.create!(
      life_area: @area, parent: @camp_leaf, horizon: "day",
      title: "Milestone", scheduled_on: 1.month.from_now.to_date, repeat: "none", position: 0
    )

    Strategy::CascadeToDaily.call(user: @user, life_area: @area, from: Date.current, to: Date.current)

    todo = @user.daily_todos.find_by!(strategy_goal_id: battle.id, scheduled_on: Date.current)
    assert_equal "Milestone", todo.title
    assert_equal 1.month.from_now.to_date, battle.reload.scheduled_on
  end

  test "cap skips excess one-shots without surfacing todos" do
    @camp_leaf = practice_leaf_for!(@camp)
    25.times do |i|
      @user.strategy_goals.create!(
        life_area: @area, parent: @camp_leaf, horizon: "day",
        title: "Battle #{i}", scheduled_on: 1.month.from_now.to_date, repeat: "none", position: i
      )
    end

    Strategy::CascadeToDaily.call(user: @user, life_area: @area, from: Date.current, to: Date.current)

    assert_equal GameRules::MAX_DAILY_TODOS, GameRules.daily_open_count(@user, Date.current)
    assert_equal 5, Today::BattlesWaiting.count(user: @user, life_area: @area)
  end

  test "completing open todos frees slots for waiting one-shots" do
    @camp_leaf = practice_leaf_for!(@camp)
    25.times do |i|
      @user.strategy_goals.create!(
        life_area: @area, parent: @camp_leaf, horizon: "day",
        title: "Battle #{i}", scheduled_on: 1.month.from_now.to_date, repeat: "none", position: i
      )
    end

    Strategy::CascadeToDaily.call(user: @user, life_area: @area, from: Date.current, to: Date.current)
    assert_equal GameRules::MAX_DAILY_TODOS, GameRules.daily_open_count(@user, Date.current)
    assert_equal 5, Today::BattlesWaiting.count(user: @user, life_area: @area)

    @user.daily_todos.for_day(Date.current).incomplete.limit(15).find_each do |todo|
      todo.update!(completed_at: Time.current)
    end
    assert_equal 5, GameRules.daily_open_count(@user, Date.current)

    Strategy::CascadeToDaily.call(user: @user, life_area: @area, from: Date.current, to: Date.current)

    assert_equal GameRules::MAX_DAILY_TODOS, GameRules.daily_open_count(@user, Date.current)
    assert_equal 0, Today::BattlesWaiting.count(user: @user, life_area: @area)
    assert_operator @user.daily_todos.for_day(Date.current).count, :>, GameRules::MAX_DAILY_TODOS
  end

  test "one-time completed todo is not recreated" do
    @camp_leaf = practice_leaf_for!(@camp)
    practice = @user.strategy_goals.create!(
      life_area: @area, parent: @camp_leaf, horizon: "day",
      title: "Once", scheduled_on: Date.current, repeat: "none", position: 0
    )
    Strategy::CascadeToDaily.call(user: @user, life_area: @area, from: Date.current, to: Date.current)
    todo = @user.daily_todos.find_by!(strategy_goal_id: practice.id, scheduled_on: Date.current)
    todo.update!(completed_at: Time.current)
    practice.complete!

    created = Strategy::CascadeToDaily.call(
      user: @user, life_area: @area, from: Date.current, to: Date.current + 1.day
    )
    assert_equal 0, created
    assert_equal 1, @user.daily_todos.where(strategy_goal_id: practice.id).count
  end

  test "at cap does not attach unsaved todos to user association" do
    @camp_leaf = practice_leaf_for!(@camp)
    18.times do |i|
      @user.strategy_goals.create!(
        life_area: @area, parent: @camp_leaf, horizon: "day",
        title: "Sync daily #{i}", scheduled_on: Date.current - 1.month, repeat: "daily", position: i
      )
    end

    while GameRules.daily_open_count(@user, Date.current) < GameRules::MAX_DAILY_TODOS
      n = @user.daily_todos.for_day(Date.current).count
      @user.daily_todos.create!(
        title: "Cap filler #{n}",
        aspect_key: "self",
        scheduled_on: Date.current,
        position: n,
        lp_reward: GameRules::BATTLE_TODO_LP
      )
    end
    assert_equal GameRules::MAX_DAILY_TODOS, GameRules.daily_open_count(@user, Date.current)

    @user.daily_todos.to_a

    Strategy::CascadeToDaily.call(
      user: @user, life_area: @area, from: Date.current.beginning_of_week, to: Date.current.end_of_week
    )

    assert @user.daily_todos.none?(&:new_record?)
  end
end
