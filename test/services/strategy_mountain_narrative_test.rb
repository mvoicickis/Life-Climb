# frozen_string_literal: true

require "test_helper"

class StrategyMountainNarrativeTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @area = @user.life_areas.first || @user.life_areas.create!(key: "career", label: "Career", position: 0)
  end

  test "foothill reads as Base camp" do
    goal = @user.strategy_goals.create!(life_area: @area, horizon: "goal", title: "Goal", position: 0)
    mountain = Strategy::Mountain.for(goal: goal)
    assert_equal :foothill, mountain[:stage]
    assert_match(/Base camp/i, mountain[:label])
  end

  test "flags with mid progress reads Halfway ridge" do
    goal = @user.strategy_goals.create!(life_area: @area, horizon: "goal", title: "Goal", position: 0)
    plan = @user.strategy_goals.create!(life_area: @area, parent: goal, horizon: "plan", title: "Plan", position: 0)
    done = @user.strategy_goals.create!(life_area: @area, parent: plan, horizon: "project", title: "Done", position: 0)
    open = @user.strategy_goals.create!(life_area: @area, parent: plan, horizon: "project", title: "Open", position: 1)
    done.complete!
    mountain = Strategy::Mountain.for(goal: goal.reload)
    assert_equal :flags, mountain[:stage]
    assert_operator mountain[:progress], :>=, 40
    assert_match(/Halfway ridge|Flags raised|Final ascent/i, mountain[:label])
    assert_equal false, open.completed?
  end
end
