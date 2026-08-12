# frozen_string_literal: true

require "test_helper"

class Strategy::WeeklyPlanner::EngineTest < ActiveSupport::TestCase
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

  test "current starts at pick_source and persists weekly_planner cursor" do
    travel_to Date.new(2026, 8, 10) do # Monday
      step = Strategy::WeeklyPlanner::Engine.current(
        user: @user, journey: @journey, plan_id: @plan.id
      )

      assert_equal "pick_source", step.template_id
      assert_equal "pick_source", step.kind
      assert_match(/work on this week/i, step.question)

      cursor = Strategy::WeeklyPlanner::Cursor.load(@journey.reload)
      assert_equal "in_progress", cursor["status"]
      assert_equal @plan.id, cursor["plan_id"]
      assert_equal "pick_source", cursor["template_id"]
    end
  end

  test "happy path schedules sittings and completes" do
    travel_to Date.new(2026, 8, 10) do # Monday
      answer!("Polish resume")
      step = Strategy::WeeklyPlanner::Engine.current(user: @user, journey: @journey, plan_id: @plan.id)
      assert_equal "pick_count", step.template_id
      assert step.count_options.size.between?(1, 3)

      answer!("2")
      step = Strategy::WeeklyPlanner::Engine.current(user: @user, journey: @journey, plan_id: @plan.id)
      assert_equal "pick_days", step.template_id
      assert_equal 2, step.sitting_count
      assert step.eligible_dates.size >= 2

      dates = step.eligible_dates.first(2).map(&:iso8601)
      result = answer!(dates)
      assert result.next_step.completed?
      assert_equal "completed", Strategy::WeeklyPlanner::Cursor.load(@journey.reload)["status"]

      days = @user.strategy_goals.for_kind("day").where(title: "Polish resume")
      assert_equal 2, days.count
      assert_equal dates.map { |d| Date.iso8601(d) }.sort, days.map(&:scheduled_on).sort
    end
  end

  test "resume mid-flow continues without duplicating" do
    travel_to Date.new(2026, 8, 10) do
      answer!("Polish resume")
      answer!("2")
      step = Strategy::WeeklyPlanner::Engine.current(user: @user, journey: @journey, plan_id: @plan.id)
      assert_equal "pick_days", step.template_id

      step2 = Strategy::WeeklyPlanner::Engine.current(user: @user, journey: @journey.reload, plan_id: @plan.id)
      assert_equal "pick_days", step2.template_id
      assert_equal "Polish resume", step2.title
      assert_equal 0, @user.strategy_goals.for_kind("day").where(title: "Polish resume").count
    end
  end

  test "count is capped by remaining eligible days and commitment" do
    travel_to Date.new(2026, 8, 10) do
      @journey.update!(commitment_battle_count: 10)
      # Fill all but two remaining weekdays to the daily cap
      week = (Date.current..Date.current.end_of_week).to_a
      week[0..-3].each do |date|
        fill_day!(date)
      end

      answer!("Focus work")
      step = Strategy::WeeklyPlanner::Engine.current(user: @user, journey: @journey, plan_id: @plan.id)
      assert_equal "pick_count", step.template_id
      assert_equal 2, step.count_options.size
      assert_match(/Only 2 open days/i, step.cap_note.to_s)
    end
  end

  test "rejects past and out-of-week dates on pick_days" do
    travel_to Date.new(2026, 8, 10) do
      answer!("Focus work")
      answer!("1")
      error = assert_raises(ArgumentError) { answer!([ (Date.current - 1).iso8601 ]) }
      assert_match(/open days|sittings/i, error.message)

      error = assert_raises(ArgumentError) { answer!([ (Date.current.end_of_week + 1).iso8601 ]) }
      assert_match(/open days|sittings/i, error.message)
    end
  end

  test "sunday with fewer than 2 eligible dates shows week nearly done not dead-end" do
    travel_to Date.new(2026, 8, 16) do # Sunday
      step = Strategy::WeeklyPlanner::Engine.current(
        user: @user, journey: @journey, plan_id: @plan.id
      )
      assert step.week_nearly_done?
      refute step.week_exhausted?
      assert_match(/almost wrapped/i, step.question)
      assert_match(/Monday/i, step.notice)
      assert_no_match(/missed|failed|should have/i, "#{step.question} #{step.notice}")
    end
  end

  test "mid-week exhausted days show calm dead-end" do
    travel_to Date.new(2026, 8, 12) do # Wednesday
      (Date.current..Date.current.end_of_week).each { |d| fill_day!(d) }

      step = Strategy::WeeklyPlanner::Engine.current(
        user: @user, journey: @journey, plan_id: @plan.id
      )
      assert step.week_exhausted?
      refute step.week_nearly_done?
      assert_match(/No open days/i, step.question)
    end
  end

  test "starting weekly planner leaves companion_guide cursor untouched" do
    travel_to Date.new(2026, 8, 10) do
      companion = Strategy::CompanionGuide::Cursor.start!(@journey, goal: @goal)
      companion = companion.merge("template_id" => "create_project", "plan_id" => @plan.id)
      Strategy::CompanionGuide::Cursor.save!(@journey, companion)
      before = Strategy::CompanionGuide::Cursor.load(@journey.reload).dup

      Strategy::WeeklyPlanner::Engine.current(user: @user, journey: @journey, plan_id: @plan.id)
      answer!("Weekly title")

      after = Strategy::CompanionGuide::Cursor.load(@journey.reload)
      assert_equal before, after
      assert_equal "in_progress", after["status"]
      assert_equal "create_project", after["template_id"]
      assert Strategy::WeeklyPlanner::Cursor.load(@journey)["title"] == "Weekly title"
    end
  end

  test "starting companion guide leaves weekly_planner cursor untouched" do
    travel_to Date.new(2026, 8, 10) do
      Strategy::WeeklyPlanner::Engine.current(user: @user, journey: @journey, plan_id: @plan.id)
      answer!("Keep this title")
      before = Strategy::WeeklyPlanner::Cursor.load(@journey.reload).dup

      Strategy::CompanionGuide::Engine.current(user: @user, journey: @journey)
      Strategy::CompanionGuide::Engine.answer!(
        user: @user, journey: @journey, value: "Companion plan"
      )

      after = Strategy::WeeklyPlanner::Cursor.load(@journey.reload)
      assert_equal before, after
      assert_equal "Keep this title", after["title"]
      assert_equal "pick_count", after["template_id"]
      companion = Strategy::CompanionGuide::Cursor.load(@journey)
      assert_equal "in_progress", companion["status"]
      refute_equal "pick_count", companion["template_id"]
    end
  end

  test "pick_source offers incomplete practice tasks as title sources" do
    travel_to Date.new(2026, 8, 10) do
      leaf = practice_leaf_for!(@project)
      host = Strategy::EnsureFolderQuest.call(folder: leaf)
      task = host.practice_tasks.create!(user: @user, title: "Do a lesson", position: 0)

      step = Strategy::WeeklyPlanner::Engine.current(user: @user, journey: @journey, plan_id: @plan.id)
      values = step.source_options.map { |o| o[:value] }
      assert_includes values, "task:#{task.id}"

      answer!("task:#{task.id}")
      cursor = Strategy::WeeklyPlanner::Cursor.load(@journey.reload)
      assert_equal "Do a lesson", cursor["title"]
      assert_equal task.id, cursor["source_practice_task_id"]
    end
  end

  private

  def answer!(value)
    Strategy::WeeklyPlanner::Engine.answer!(
      user: @user,
      journey: @journey,
      value: value,
      plan_id: @plan.id
    )
  end

  def fill_day!(date)
    GameRules::MAX_DAILY_TODOS.times do |i|
      @user.daily_todos.create!(
        title: "Fill #{date}-#{i}",
        scheduled_on: date,
        position: i,
        aspect_key: @area.key,
        lp_reward: GameRules::BATTLE_TODO_LP
      )
    end
  end
end
