# frozen_string_literal: true

require "test_helper"

class Climb::RewardTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Ship LifePoints",
      ideal_scene: "App in production",
      current_reality: "Still building",
      next_win: "Launch Beta",
      today_mission: "Write one test",
      closer_percent: 20
    )
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    @goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Year goal", position: 0
    )
    @plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @goal, horizon: "plan", title: "Plan", position: 0
    )
    @projects = 3.times.map do |n|
      @user.strategy_goals.create!(
        life_area: @area, life_journey: @journey, parent: @plan, horizon: "project",
        title: "Camp #{n + 1}", position: n
      )
    end
  end

  test "completing one camp of three moves percent but returns project not boss" do
    @projects.first.complete!
    Strategy::SyncCompletion.call(project: @projects.first)

    before_mountain = Strategy::Mountain.for(goal: @goal.reload)
    assert_equal :flags, before_mountain[:stage]
    assert_equal 33, before_mountain[:progress]

    @projects.second.complete!
    Strategy::SyncCompletion.call(project: @projects.second)

    after_mountain = Strategy::Mountain.for(goal: @goal.reload)
    assert_equal before_mountain[:stage], after_mountain[:stage]
    assert_operator after_mountain[:progress], :>, before_mountain[:progress]
    assert_equal 67, after_mountain[:progress]

    reward = Climb::Reward.for_project(
      user: @user,
      goal: @goal.reload,
      percent_before: before_mountain[:progress],
      percent_after: after_mountain[:progress],
      stage_before: before_mountain[:stage]
    )

    assert_equal "project", reward[:kind]
    refute_equal "boss", reward[:kind]
  end
end
