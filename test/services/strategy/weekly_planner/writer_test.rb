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

  test "creates dated day goals for each item and cascades to daily todos" do
    today = Date.current
    dates = [ today, today + 1 ].select { |d| d <= today.end_of_week }
    skip "need at least 2 eligible days this week" if dates.size < 2

    cursor = {
      "items" => [
        { "title" => "Polish resume", "selected_dates" => [ dates[0].iso8601 ] },
        { "title" => "Ship landing", "selected_dates" => [ dates[1].iso8601 ] }
      ],
      "project_id" => @project.id
    }

    result = nil
    assert_difference -> { @user.strategy_goals.for_kind("day").count }, 2 do
      result = Strategy::WeeklyPlanner::Writer.call(user: @user, journey: @journey, cursor: cursor)
    end

    assert_equal "completed", result["status"]
    assert_equal 2, result["created_count"]
    assert_equal [], result["skipped"]
    assert @user.daily_todos.for_day(dates[0]).exists?(title: "Polish resume")
    assert @user.daily_todos.for_day(dates[1]).exists?(title: "Ship landing")
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
        "items" => [
          {
            "title" => task.title,
            "source_practice_task_id" => task.id,
            "selected_dates" => [ today.iso8601 ]
          }
        ],
        "project_id" => @project.id
      }
    )

    task.reload
    assert_nil task.completed_at
    assert_equal before["title"], task.title
    assert_equal before["strategy_goal_id"], task.strategy_goal_id
  end

  test "reports skipped days when the day is already at cap without creating orphans" do
    today = Date.current
    GameRules::MAX_DAILY_TODOS.times do |i|
      @user.daily_todos.create!(
        title: "Fill #{i}",
        scheduled_on: today,
        position: i,
        aspect_key: @area.key,
        lp_reward: GameRules::BATTLE_TODO_LP
      )
    end

    other = (today + 1)
    skip "need another day this week" if other > today.end_of_week

    before_days = @user.strategy_goals.for_kind("day").count
    result = Strategy::WeeklyPlanner::Writer.call(
      user: @user,
      journey: @journey,
      cursor: {
        "items" => [
          {
            "title" => "Full day work",
            "selected_dates" => [ today.iso8601, other.iso8601 ]
          }
        ],
        "project_id" => @project.id
      }
    )

    assert_equal 1, result["created_count"]
    assert_equal 1, result["skipped"].size
    assert_equal today.iso8601, result["skipped"].first["date"]
    assert_equal "Full day work", result["skipped"].first["title"]
    assert_equal before_days + 1, @user.strategy_goals.for_kind("day").count
    assert @user.daily_todos.for_day(other).exists?(title: "Full day work")
    refute @user.daily_todos.for_day(today).exists?(title: "Full day work")
  end

  test "rejects empty selected dates" do
    error = assert_raises(ArgumentError) do
      Strategy::WeeklyPlanner::Writer.call(
        user: @user,
        journey: @journey,
        cursor: {
          "items" => [ { "title" => "No days", "selected_dates" => [] } ],
          "project_id" => @project.id
        }
      )
    end
    assert_match(/at least one open day/i, error.message)
  end

  private

  def practice_leaf_for!(project)
    Battles::PracticeParent.call(user: @user, project: project)
  end
end
