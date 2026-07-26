# frozen_string_literal: true

require "test_helper"

class StrategyBattleAnglesTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @area = life_areas(:one_self)
    @goal = @user.strategy_goals.create!(life_area: @area, horizon: "goal", title: "Goal", position: 0)
    @plan = @user.strategy_goals.create!(life_area: @area, parent: @goal, horizon: "plan", title: "Plan", position: 0)
    @project = @user.strategy_goals.create!(
      life_area: @area, parent: @plan, horizon: "project", title: "Cut spend", position: 0
    )
  end

  test "suggests sharper titles from project and last battle" do
    battle = @user.strategy_goals.create!(
      life_area: @area, parent: @project, horizon: "day",
      title: "Cancel subscription", scheduled_on: Date.current, position: 0
    )
    battle.complete!

    angles = Strategy::BattleAngles.for(project: @project)
    assert_equal 3, angles.size
    assert angles.any? { |a| a.include?("Cut spend") }
    assert angles.any? { |a| a.include?("Cancel subscription") }
  end

  test "skips titles that already exist under the project" do
    existing = I18n.t("dash.battle_angles.templates.fifteen", project: "Cut spend")
    @user.strategy_goals.create!(
      life_area: @area, parent: @project, horizon: "day",
      title: existing, scheduled_on: Date.current, position: 0
    )

    angles = Strategy::BattleAngles.for(project: @project)
    assert_not_includes angles, existing
    assert_operator angles.size, :<=, 3
  end
end
