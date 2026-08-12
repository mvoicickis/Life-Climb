# frozen_string_literal: true

require "test_helper"

class Strategy::WeeklyPlanner::WriterTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Ship LifePoints",
      ideal_scene: "App live",
      current_reality: "Building",
      next_win: "Launch",
      today_mission: "Write tests",
      closer_percent: 20,
      route_mission: true
    )
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    @plan = @goal.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: "Main trail", position: 0
    )
    @project = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Resume", position: 0
    )
    @journey.update!(commitment_battle_count: 3)
  end

  test "creates dated day goals under practice leaf and cascades to daily todos" do
    today = Date.current
    dates = [ today, today + 1 ].select { |d| d <= today.end_of_week }
    skip "need at least 2 eligible days this week" if dates.size < 2

    cursor = {
      "title" => "Polish resume",
      "sitting_count" => 2,
      "selected_dates" => dates.map(&:iso8601),
      "project_id" => @project.id
    }

    assert_difference -> { @user.strategy_goals.for_kind("day").where(title: "Polish resume").count }, 2 do
      Strategy::WeeklyPlanner::Writer.call(user: @user, journey: @journey, cursor: cursor)
    end

    days = @user.strategy_goals.for_kind("day").where(title: "Polish resume").order(:scheduled_on)
    assert_equal dates.sort, days.map(&:scheduled_on)
    days.each do |day|
      assert day.parent.project?
      assert_equal @project.id, day.parent.parent_id
    end

    dates.each do |date|
      assert @user.daily_todos.for_day(date).exists?(title: "Polish resume")
    end
  end

  test "does not mutate practice task rows when sourcing a title" do
    leaf = practice_leaf_for!(@project)
    host = Strategy::EnsureFolderQuest.call(folder: leaf)
    task = host.practice_tasks.create!(user: @user, title: "Do a lesson", position: 0)
    before = task.attributes

    today = Date.current
    Strategy::WeeklyPlanner::Writer.call(
      user: @user,
      journey: @journey,
      cursor: {
        "title" => task.title,
        "source_practice_task_id" => task.id,
        "sitting_count" => 1,
        "selected_dates" => [ today.iso8601 ],
        "project_id" => @project.id
      }
    )

    task.reload
    assert_nil task.completed_at
    assert_equal before["title"], task.title
    assert_equal before["strategy_goal_id"], task.strategy_goal_id
  end

  test "rejects dates outside eligible set" do
    past = Date.current - 1
    error = assert_raises(ArgumentError) do
      Strategy::WeeklyPlanner::Writer.call(
        user: @user,
        journey: @journey,
        cursor: {
          "title" => "Late work",
          "sitting_count" => 1,
          "selected_dates" => [ past.iso8601 ],
          "project_id" => @project.id
        }
      )
    end
    assert_match(/Pick 1 day to continue/i, error.message)
  end

  test "rejects count mismatch" do
    today = Date.current
    error = assert_raises(ArgumentError) do
      Strategy::WeeklyPlanner::Writer.call(
        user: @user,
        journey: @journey,
        cursor: {
          "title" => "Mismatch",
          "sitting_count" => 2,
          "selected_dates" => [ today.iso8601 ],
          "project_id" => @project.id
        }
      )
    end
    assert_match(/Pick 2 days to continue/i, error.message)
  end
end
