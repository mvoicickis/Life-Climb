# frozen_string_literal: true

require "test_helper"

class Today::BattlesWaitingTest < ActiveSupport::TestCase
  include ClimbTestHelper

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
    @camp_leaf = practice_leaf_for!(@camp)
  end

  test "counts eligible battles without an open todo today" do
    21.times do |i|
      @user.strategy_goals.create!(
        life_area: @area, parent: @camp_leaf, horizon: "day",
        title: "Battle #{i}", scheduled_on: 1.month.from_now.to_date, repeat: "none", position: i
      )
    end
    Strategy::CascadeToDaily.call(user: @user, life_area: @area, from: Date.current, to: Date.current)

    assert_equal GameRules::MAX_DAILY_TODOS, @user.daily_todos.for_day.count
    assert_equal 1, Today::BattlesWaiting.count(user: @user, life_area: @area)
  end

  test "returns zero when every eligible battle has an open todo" do
    battle = @user.strategy_goals.create!(
      life_area: @area, parent: @camp_leaf, horizon: "day",
      title: "Ready", scheduled_on: Date.current, repeat: "none", position: 0
    )
    Strategy::CascadeToDaily.call(user: @user, life_area: @area, from: Date.current, to: Date.current)

    assert_equal 0, Today::BattlesWaiting.count(user: @user, life_area: @area)
    assert @user.daily_todos.for_day.exists?(strategy_goal_id: battle.id)
  end
end
