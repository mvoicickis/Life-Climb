# frozen_string_literal: true

require "test_helper"

class StrategyGoalEffortTierTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @area = @user.life_areas.first || @user.life_areas.create!(key: "career", number: 99, position: 99)
    @goal = @user.strategy_goals.create!(life_area: @area, horizon: "goal", title: "G", position: 0)
    @plan = @user.strategy_goals.create!(
      life_area: @area, parent: @goal, horizon: "plan", title: "P", position: 0
    )
  end

  test "accepts allowlisted effort tiers and blanks to nil" do
    @plan.update!(effort_tier: "steady")
    assert_equal "steady", @plan.reload.effort_tier

    @plan.update!(effort_tier: "  ")
    assert_nil @plan.reload.effort_tier
  end

  test "rejects invalid effort tiers" do
    @plan.effort_tier = "extreme"
    assert_not @plan.valid?
    assert_includes @plan.errors[:effort_tier], "is not included in the list"
  end

  test "nil effort_tier is allowed" do
    @plan.effort_tier = nil
    assert @plan.valid?
  end
end
