# frozen_string_literal: true

require "test_helper"

class Strategy::EnsureFolderQuestTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    Onboarding::Run.call(
      user: @user, area_key: "career", title: "Ship",
      ideal_scene: "Live", current_reality: "Building", next_win: "Launch",
      today_mission: "Build", closer_percent: 20, route_mission: true
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
      horizon: "project", title: "Vocabulary", position: 0
    )
  end

  test "creates a checklist host day under a path-level camp and cascades to Today" do
    host = Strategy::EnsureFolderQuest.call(folder: @section)
    assert host.day?
    assert_equal Strategy::EnsureFolderQuest::HOST_TITLE, host.title
    assert_equal @section.id, host.parent_id
    todo = @user.daily_todos.for_day(Date.current).find_by(strategy_goal_id: host.id)
    assert_equal "Vocabulary", todo.title
  end

  test "second call returns the same host day id" do
    first = Strategy::EnsureFolderQuest.call(folder: @section)
    second = Strategy::EnsureFolderQuest.call(folder: @section)
    assert_equal first.id, second.id
    assert_equal 1, @section.children.where(horizon: "day").count
  end

  test "prefers existing Checklist title over older days" do
    older = @section.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Legacy quest", scheduled_on: Date.current, position: 0
    )
    checklist = @section.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: Strategy::EnsureFolderQuest::HOST_TITLE,
      scheduled_on: Date.current, position: 1
    )

    host = Strategy::EnsureFolderQuest.call(folder: @section)
    assert_equal checklist.id, host.id
    assert_not_equal older.id, host.id
  end

  test "plan does not create a host" do
    assert_raises(ArgumentError) { Strategy::EnsureFolderQuest.call(folder: @plan) }
  end
end
