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

  test "current starts at build_items and persists weekly_planner cursor" do
    travel_to Date.new(2026, 8, 10) do # Monday
      step = Strategy::WeeklyPlanner::Engine.current(
        user: @user, journey: @journey, plan_id: @plan.id
      )

      assert_equal "build_items", step.template_id
      assert_equal "build_items", step.kind
      assert_match(/work on this week/i, step.question)

      cursor = Strategy::WeeklyPlanner::Cursor.load(@journey.reload)
      assert_equal "in_progress", cursor["status"]
      assert_equal @plan.id, cursor["plan_id"]
      assert_equal "build_items", cursor["template_id"]
      assert_equal 2, cursor["version"]
      assert_equal [], cursor["items"]
    end
  end

  test "happy path schedules multiple items across days and completes" do
    travel_to Date.new(2026, 8, 10) do # Monday
      answer!({ action: "add_item", title: "Polish resume" })
      answer!({ action: "add_item", title: "Ship landing" })
      step = Strategy::WeeklyPlanner::Engine.current(user: @user, journey: @journey, plan_id: @plan.id)
      assert_equal "build_items", step.template_id
      assert_equal 2, step.items.size

      answer!({ action: "continue" })
      step = Strategy::WeeklyPlanner::Engine.current(user: @user, journey: @journey, plan_id: @plan.id)
      assert_equal "pick_days", step.template_id
      assert_equal "Polish resume", step.title
      assert_match(/Item 1 of 2/i, step.item_progress)
      assert step.eligible_dates.size >= 2

      d1, d2 = step.eligible_dates.first(2)
      answer!({ action: "pick_days", dates: [ d1.iso8601 ] })

      step = Strategy::WeeklyPlanner::Engine.current(user: @user, journey: @journey, plan_id: @plan.id)
      assert_equal "pick_days", step.template_id
      assert_equal "Ship landing", step.title
      assert_match(/Item 2 of 2/i, step.item_progress)

      result = answer!({ action: "pick_days", dates: [ d2.iso8601 ] })
      assert result.next_step.completed?
      assert_equal "completed", Strategy::WeeklyPlanner::Cursor.load(@journey.reload)["status"]
      assert_match(/2 things set across 2 day slots/i, result.ack)

      assert_equal 1, @user.strategy_goals.for_kind("day").where(title: "Polish resume").count
      assert_equal 1, @user.strategy_goals.for_kind("day").where(title: "Ship landing").count
      assert @user.daily_todos.for_day(d1).exists?(title: "Polish resume")
      assert @user.daily_todos.for_day(d2).exists?(title: "Ship landing")
    end
  end

  test "continue with ActionController::Parameters items does not dump hash into title" do
    travel_to Date.new(2026, 8, 10) do
      params_items = [ ActionController::Parameters.new("title" => "Get a job") ]
      answer!({ action: "continue", items: params_items })
      step = Strategy::WeeklyPlanner::Engine.current(user: @user, journey: @journey, plan_id: @plan.id)
      assert_equal "Get a job", step.title
      refute_includes step.title, "=>"

      cursor = Strategy::WeeklyPlanner::Cursor.load(@journey.reload)
      assert_equal "Get a job", cursor["items"].first["title"]
    end
  end

  test "build_items lists already-scheduled titles with day counts" do
    travel_to Date.new(2026, 8, 10) do # Monday
      [ Date.new(2026, 8, 10), Date.new(2026, 8, 11), Date.new(2026, 8, 12), Date.new(2026, 8, 13) ].each_with_index do |day, i|
        @user.daily_todos.create!(
          title: "Improve German",
          scheduled_on: day,
          position: i,
          aspect_key: @area.key,
          lp_reward: GameRules::BATTLE_TODO_LP
        )
      end
      @user.daily_todos.create!(
        title: "Ship landing",
        scheduled_on: Date.new(2026, 8, 12),
        position: 10,
        aspect_key: @area.key,
        lp_reward: GameRules::BATTLE_TODO_LP
      )

      step = Strategy::WeeklyPlanner::Engine.current(user: @user, journey: @journey, plan_id: @plan.id)
      assert_equal "build_items", step.kind
      assert_equal [
        { title: "Improve German", days: 4 },
        { title: "Ship landing", days: 1 }
      ], step.already_this_week
    end
  end

  test "build_items already_this_week is empty when nothing is scheduled" do
    travel_to Date.new(2026, 8, 10) do
      step = Strategy::WeeklyPlanner::Engine.current(user: @user, journey: @journey, plan_id: @plan.id)
      assert_equal [], step.already_this_week
    end
  end

  test "resumes mid-loop at the same item index" do
    travel_to Date.new(2026, 8, 10) do
      answer!({ action: "continue", items: [ "Alpha", "Beta", "Gamma" ] })
      d1 = Strategy::WeeklyPlanner::Definition.eligible_dates(@user).first
      answer!({ action: "pick_days", dates: [ d1.iso8601 ] })

      cursor = Strategy::WeeklyPlanner::Cursor.load(@journey.reload)
      assert_equal 1, cursor["item_index"]
      assert_equal "Beta", cursor["items"][1]["title"]

      step = Strategy::WeeklyPlanner::Engine.current(user: @user, journey: @journey, plan_id: @plan.id)
      assert_equal "pick_days", step.template_id
      assert_equal "Beta", step.title
      assert_match(/Item 2 of 3/i, step.item_progress)
    end
  end

  test "count is not capped by commitment — only by eligible days" do
    travel_to Date.new(2026, 8, 10) do
      @journey.update!(commitment_battle_count: 1)
      answer!({ action: "continue", items: [ "Focus work" ] })
      step = Strategy::WeeklyPlanner::Engine.current(user: @user, journey: @journey, plan_id: @plan.id)
      assert_equal "pick_days", step.template_id
      # Full remaining week (Mon–Sun) should be offered despite commitment 1.
      assert_operator step.eligible_dates.size, :>=, 5
    end
  end

  test "item 1 filling a day makes it unavailable for item 2 with no skip" do
    travel_to Date.new(2026, 8, 10) do
      # Leave only 1 seat on Monday; other days have room.
      monday = Date.current
      (GameRules::MAX_DAILY_TODOS - 1).times do |i|
        @user.daily_todos.create!(
          title: "Fill Mon #{i}",
          scheduled_on: monday,
          position: i,
          aspect_key: @area.key,
          lp_reward: GameRules::BATTLE_TODO_LP
        )
      end

      answer!({ action: "continue", items: [ "First", "Second" ] })
      step = Strategy::WeeklyPlanner::Engine.current(user: @user, journey: @journey, plan_id: @plan.id)
      assert_includes step.eligible_dates, monday

      answer!({ action: "pick_days", dates: [ monday.iso8601 ] })
      step = Strategy::WeeklyPlanner::Engine.current(user: @user, journey: @journey, plan_id: @plan.id)
      assert_equal "Second", step.title
      refute_includes step.eligible_dates, monday

      other = step.eligible_dates.first
      result = answer!({ action: "pick_days", dates: [ other.iso8601 ] })
      assert result.next_step.completed?
      cursor = Strategy::WeeklyPlanner::Cursor.load(@journey.reload)
      assert_equal [], cursor["skipped"]
      assert_equal 2, cursor["created_count"]
    end
  end

  test "legacy v1 cursor resets to build_items with tree_changed notice" do
    travel_to Date.new(2026, 8, 10) do
      flags = (@journey.setup_flags.presence || {}).stringify_keys.merge(
        "weekly_planner" => {
          "version" => 1,
          "status" => "in_progress",
          "template_id" => "pick_count",
          "plan_id" => @plan.id,
          "title" => "Old flow",
          "sitting_count" => 2,
          "selected_dates" => []
        }
      )
      @journey.update_columns(setup_flags: flags, updated_at: Time.current)
      @journey.setup_flags = flags

      step = Strategy::WeeklyPlanner::Engine.current(user: @user, journey: @journey, plan_id: @plan.id)
      assert_equal "build_items", step.template_id
      assert_match(/mountain moved|safe spot/i, step.notice.to_s)
      cursor = Strategy::WeeklyPlanner::Cursor.load(@journey.reload)
      assert_equal 2, cursor["version"]
      assert_equal [], cursor["items"]
    end
  end

  test "rejects past and out-of-week dates on pick_days" do
    travel_to Date.new(2026, 8, 10) do
      answer!({ action: "continue", items: [ "Focus work" ] })
      error = assert_raises(ArgumentError) { answer!({ action: "pick_days", dates: [ (Date.current - 1).iso8601 ] }) }
      assert_match(/at least one open day/i, error.message)

      error = assert_raises(ArgumentError) { answer!({ action: "pick_days", dates: [ (Date.current.end_of_week + 1).iso8601 ] }) }
      assert_match(/at least one open day/i, error.message)
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

  test "filled week shows exhausted terminal" do
    travel_to Date.new(2026, 8, 12) do
      (Date.current..Date.current.end_of_week).each { |date| fill_day!(date) }
      step = Strategy::WeeklyPlanner::Engine.current(user: @user, journey: @journey, plan_id: @plan.id)
      assert step.week_exhausted?
      assert_match(/No open days left this week/i, step.question)
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
