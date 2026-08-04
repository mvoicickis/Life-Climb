# frozen_string_literal: true

require "test_helper"

class StrategyGoalColorKeyTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @area = @user.life_areas.first || @user.life_areas.create!(key: "career", title: "Career")
    @goal = @user.strategy_goals.create!(life_area: @area, horizon: "goal", title: "G", position: 0)
    @plan = @user.strategy_goals.create!(
      life_area: @area, parent: @goal, horizon: "plan", title: "P", position: 0
    )
    @section = @user.strategy_goals.create!(
      life_area: @area, parent: @plan, horizon: "project", title: "Section", position: 0
    )
  end

  test "accepts curated color keys and blanks to nil" do
    quest = @user.strategy_goals.create!(
      life_area: @area, parent: @section, horizon: "project",
      title: "Purple quest", position: 0, color_key: "purple"
    )
    assert_equal "purple", quest.tagged_color_key

    quest.update!(color_key: "  ")
    assert_nil quest.reload.color_key
    assert_nil quest.tagged_color_key
  end

  test "rejects invalid color keys" do
    quest = @user.strategy_goals.build(
      life_area: @area, parent: @section, horizon: "project",
      title: "Bad", position: 0, color_key: "neon"
    )
    assert_not quest.valid?
    assert_includes quest.errors[:color_key], "is not included in the list"
  end
end
