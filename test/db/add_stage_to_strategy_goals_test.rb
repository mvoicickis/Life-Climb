# frozen_string_literal: true

require "test_helper"
require Rails.root.join("db/migrate/20260912140000_add_stage_to_strategy_goals.rb")

class AddStageToStrategyGoalsTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    allow_extra_climbs!(@user)
    @area = @user.life_areas.first || @user.life_areas.create!(key: "career", number: 9)
    @goal = @user.strategy_goals.create!(life_area: @area, horizon: "goal", title: "Backfill goal", position: 0)
    @plan = @user.strategy_goals.create!(
      life_area: @area, parent: @goal, horizon: "plan", title: "Backfill plan", position: 0
    )
  end

  test "backfill_stages assigns sequential stages by position then id" do
    third = @user.strategy_goals.create!(
      life_area: @area, parent: @plan, horizon: "project", title: "Third", position: 2, stage: 0
    )
    first = @user.strategy_goals.create!(
      life_area: @area, parent: @plan, horizon: "project", title: "First", position: 0, stage: 0
    )
    second = @user.strategy_goals.create!(
      life_area: @area, parent: @plan, horizon: "project", title: "Second", position: 1, stage: 0
    )
    plan_completed_at = @plan.completed_at
    first_completed_at = first.completed_at

    AddStageToStrategyGoals.send(:backfill_stages!)

    assert_equal [ 0, 1, 2 ], [ first, second, third ].map { |camp| camp.reload.stage }
    assert_equal plan_completed_at, @plan.reload.completed_at
    assert_equal first_completed_at, first.reload.completed_at
  end
end
