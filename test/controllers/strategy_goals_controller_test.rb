# frozen_string_literal: true

require "test_helper"

class StrategyGoalsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
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
  end

  test "journey show is guided strategy without climb chrome" do
    get life_journey_path(@journey)
    assert_response :success
    assert_match(/This season.?s mountain|Your year plan/i, response.body)
    assert_match(/Next up/i, response.body)
    assert_match(/Quest path|Goal/i, response.body)
    assert_match(/Strategy Points/i, response.body)
    assert_select ".lp-strategy-path"
    assert_select ".lp-strategy-path__checkpoint"
    assert_select ".lp-strategy-next"
    assert_select "#next-up-title"
    assert_select ".lp-strategy__universe", count: 0
    assert_no_match(/Climb clarity/i, response.body)
  end

  test "goal create celebrates with sp_gained flash and awards goal SP" do
    post strategy_goals_path, params: {
      life_area_id: @area.id,
      life_journey_id: @journey.id,
      horizon: "goal",
      title: "Become a Rails developer"
    }
    goal = @user.strategy_goals.for_kind("goal").last
    assert Strategy::YearCycle.dec29?(goal.due_on)
    assert_equal 100, @user.reload.strategy_points
    assert_match(/Goal created/i, flash[:notice].to_s)
    assert_equal 100, flash[:sp_gained].to_i
  end

  test "next up inlines the create form instead of scrolling to board" do
    get life_journey_path(@journey)
    assert_response :success
    assert_select "#strategy-next-up form[action=?]", strategy_goals_path
    assert_select "#strategy-next-up #next-up-title"
    assert_select ".lp-strategy-next__chip"
  end

  test "remove lives behind overflow menu on quest cards" do
    goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Goal", position: 0
    )
    @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: goal, horizon: "plan", title: "Find a job", position: 0
    )
    get life_journey_path(@journey)
    assert_response :success
    assert_select ".lp-strategy-overflow"
    assert_select ".lp-strategy-quest__marker"
    assert_select ".lp-strategy-quest__xp"
  end

  test "goal locks due_on to December 29 and awards goal SP" do
    post strategy_goals_path, params: {
      life_area_id: @area.id,
      life_journey_id: @journey.id,
      horizon: "goal",
      title: "Become a Rails developer"
    }
    goal = @user.strategy_goals.for_kind("goal").last
    assert Strategy::YearCycle.dec29?(goal.due_on)
    assert_equal 100, @user.reload.strategy_points
    assert_match(/Goal created/i, flash[:notice].to_s)
  end

  test "guided tree plan project monthly goal battle awards and syncs today" do
    post strategy_goals_path, params: {
      life_area_id: @area.id, life_journey_id: @journey.id,
      horizon: "goal", title: "Become debt-free"
    }
    goal = @user.strategy_goals.for_kind("goal").last

    post strategy_goals_path, params: {
      life_area_id: @area.id, life_journey_id: @journey.id,
      parent_id: goal.id, horizon: "plan", title: "Increase income"
    }
    plan = @user.strategy_goals.for_kind("plan").last
    assert_operator @user.reload.strategy_points, :>=, 150

    post strategy_goals_path, params: {
      life_area_id: @area.id, life_journey_id: @journey.id,
      parent_id: plan.id, horizon: "project", title: "Learn German"
    }
    project = @user.strategy_goals.for_kind("project").last
    assert_operator @user.reload.strategy_points, :>=, 225

    slot = Strategy::YearCycle.remaining_month_slots(target: goal.due_on).first
    post strategy_goals_path, params: {
      life_area_id: @area.id, life_journey_id: @journey.id,
      parent_id: project.id, horizon: "month", due_on: slot[:due_on], title: "Finish A1"
    }
    month = @user.strategy_goals.for_kind("month").last

    post strategy_goals_path, params: {
      life_area_id: @area.id, life_journey_id: @journey.id,
      parent_id: month.id, horizon: "day", scheduled_on: Date.current.to_s,
      title: "Learn 20 words"
    }
    assert @user.daily_todos.for_day(Date.current).exists?(title: "Learn 20 words")
    assert_operator @user.reload.strategy_points, :>=, 725 # includes strategy complete 500
  end

  test "battles can hang under monthly goal without weeks" do
    goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Goal", position: 0
    )
    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: goal, horizon: "plan", title: "Plan", position: 0
    )
    project = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project", title: "Project", position: 0
    )
    month = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: project, horizon: "month",
      title: "July", due_on: Date.current.end_of_month, position: 0
    )
    battle = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: month, horizon: "day",
      title: "Direct battle", scheduled_on: Date.current, position: 0
    )
    assert battle.persisted?
    assert_equal 0, month.children.for_kind("week").count
  end

  test "progress rolls up when battle completed via today" do
    goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Goal", position: 0
    )
    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: goal, horizon: "plan", title: "Plan", position: 0
    )
    project = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project", title: "Project", position: 0
    )
    month = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: project, horizon: "month",
      title: "July", due_on: Date.current.end_of_month, position: 0
    )
    battle = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: month, horizon: "day",
      title: "Win this", scheduled_on: Date.current, position: 0
    )
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)
    todo = @user.daily_todos.find_by!(strategy_goal_id: battle.id)

    assert_equal 0, goal.progress_percent
    post complete_daily_todo_path(todo)
    assert_equal 100, goal.reload.progress_percent
    assert battle.reload.completed?
  end

  test "monthly goals can hang directly under a plan" do
    post strategy_goals_path, params: {
      life_area_id: @area.id, life_journey_id: @journey.id,
      horizon: "goal", title: "Become debt-free"
    }
    goal = @user.strategy_goals.for_kind("goal").last
    post strategy_goals_path, params: {
      life_area_id: @area.id, life_journey_id: @journey.id,
      parent_id: goal.id, horizon: "plan", title: "Find a job"
    }
    plan = @user.strategy_goals.for_kind("plan").last
    slot = Strategy::YearCycle.remaining_month_slots(target: goal.due_on).first

    post strategy_goals_path, params: {
      life_area_id: @area.id, life_journey_id: @journey.id,
      parent_id: plan.id, horizon: "month", due_on: slot[:due_on],
      title: "Get good German"
    }
    month = @user.strategy_goals.for_kind("month").last
    assert_equal plan.id, month.parent_id
    assert_equal "Get good German", month.title

    post strategy_goals_path, params: {
      life_area_id: @area.id, life_journey_id: @journey.id,
      parent_id: month.id, horizon: "day", scheduled_on: Date.current.to_s,
      title: "Learn 20 words"
    }
    assert @user.daily_todos.for_day(Date.current).exists?(title: "Learn 20 words")

    get life_journey_path(@journey, focus_id: plan.id)
    assert_response :success
    assert_match(/Monthly Goals/i, response.body)
    assert_match(/Get good German/i, response.body)
    assert_match(/Next up/i, response.body)
    assert_match(/This month/i, response.body)
  end

  test "progress rolls up from plan monthly goal battles" do
    goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Goal", position: 0
    )
    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: goal, horizon: "plan", title: "Find a job", position: 0
    )
    month = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "month",
      title: "Get good German", due_on: Date.current.end_of_month, position: 0
    )
    battle = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: month, horizon: "day",
      title: "Lesson 12", scheduled_on: Date.current, position: 0
    )

    assert_equal 0, plan.progress_percent
    battle.complete!
    assert_equal 100, plan.reload.progress_percent
    assert_equal 100, goal.reload.progress_percent
  end

  test "dashboard shows action points and strategy points" do
    get dashboard_path
    assert_response :success
    assert_match(/\bAP\b/, response.body)
    assert_match(/\bSP\b/, response.body)
  end
end
