# frozen_string_literal: true

require "test_helper"

class PracticeTaskTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Find a job",
      ideal_scene: "Hired",
      current_reality: "Searching",
      next_win: "Interview",
      today_mission: "Apply",
      closer_percent: 20,
      route_mission: true
    )
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    @plan = @goal.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: "Path", position: 0
    )
    @section = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "MVP", position: 0
    )
    @camp = @section.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Camp", position: 0
    )
    @practice = @camp.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Finish page", scheduled_on: Date.current, position: 0
    )
  end

  test "belongs to a day practice and can complete/reopen" do
    task = @practice.practice_tasks.create!(user: @user, title: "Design layout", position: 0)
    assert_not task.completed?
    assert_not @practice.all_objectives_complete?

    task.complete!
    assert task.completed?
    assert @practice.reload.all_objectives_complete?

    second = @practice.practice_tasks.create!(user: @user, title: "Polish header", position: 1)
    assert_not @practice.reload.all_objectives_complete?

    second.complete!
    assert @practice.reload.all_objectives_complete?

    task.reopen!
    assert_not task.completed?
    assert_not @practice.reload.all_objectives_complete?
  end

  test "rejects non-day parents" do
    task = PracticeTask.new(user: @user, strategy_goal: @camp, title: "Nope", position: 0)
    assert_not task.valid?
    assert_includes task.errors[:strategy_goal], "is invalid"
  end
end
