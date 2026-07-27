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

  test "journey show asks the goal question and inlines next up" do
    get life_journey_path(@journey)
    assert_response :success
    assert_match(/This season.?s mountain/i, response.body)
    assert_match(/Strategy wins the war\. Today wins the battle/i, response.body)
    assert_match(/What do I ultimately want to achieve/i, response.body)
    assert_match(/Next up/i, response.body)
    assert_match(/Begin Journey/i, response.body)
    assert_match(/Your mountain is waiting/i, response.body)
    assert_select ".lp-strategy-mountain.is-empty"
    assert_select "[data-controller='strategy-celebrate']"
    assert_select ".lp-strategy-path__stage.is-goal"
    assert_select ".lp-strategy-path__stage.is-plans"
    assert_select ".lp-strategy-path__stage.is-projects"
    assert_select ".lp-strategy-path__stage.is-battle"
    assert_select ".lp-strategy-next.is-goal"
    assert_select "#next-up-title"
    assert_select ".lp-strategy__universe", count: 0
    assert_no_match(/Climb clarity/i, response.body)
    assert_no_match(/This month/i, response.body)
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
    assert_equal 100, flash[:sp_gained].to_i

    get life_journey_path(@journey)
    assert_response :success
    assert_select ".lp-strategy-mountain.is-foothill"
    assert_match(/Trailhead/i, response.body)
  end

  test "guided tree goal plan project battle awards and syncs today" do
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

    post strategy_goals_path, params: {
      life_area_id: @area.id, life_journey_id: @journey.id,
      parent_id: project.id, horizon: "day", scheduled_on: Date.current.to_s,
      title: "Learn 20 words"
    }
    assert @user.daily_todos.for_day(Date.current).exists?(title: "Learn 20 words")
    assert_operator @user.reload.strategy_points, :>=, 725 # includes strategy complete 500

    get life_journey_path(@journey, focus_id: project.id)
    assert_response :success
    assert_match(/Your mountain is ready/i, response.body)
    assert_select ".lp-strategy-next.is-handoff input[type=submit][value=?]", "Fight Today's Battle"
    assert_match(/What is the very next action I can take/i, response.body)
    assert_select ".lp-strategy-overflow"
    assert_no_match(/Monthly Goals/i, response.body)
  end

  test "month horizon is rejected" do
    goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Goal", position: 0
    )
    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: goal, horizon: "plan", title: "Plan", position: 0
    )
    post strategy_goals_path, params: {
      life_area_id: @area.id, life_journey_id: @journey.id,
      parent_id: plan.id, horizon: "month", title: "July"
    }
    assert_redirected_to dashboard_path
    assert_match(/Unknown strategy step/i, flash[:alert].to_s)
    assert_equal 0, @user.strategy_goals.where(horizon: "month").count
  end

  test "battles hang directly under projects" do
    goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Goal", position: 0
    )
    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: goal, horizon: "plan", title: "Plan", position: 0
    )
    project = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project", title: "Project", position: 0
    )
    battle = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: project, horizon: "day",
      title: "Direct battle", scheduled_on: Date.current, position: 0
    )
    assert battle.persisted?
    assert_equal project.id, battle.parent_id
  end

  test "battle complete does not move goal until project confirmed" do
    goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Goal", position: 0
    )
    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: goal, horizon: "plan", title: "Plan", position: 0
    )
    project = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project", title: "Project", position: 0
    )
    battle = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: project, horizon: "day",
      title: "Win this", scheduled_on: Date.current, position: 0
    )
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)
    todo = @user.daily_todos.find_by!(strategy_goal_id: battle.id)

    assert_equal 0, goal.progress_percent
    post complete_daily_todo_path(todo)
    assert_equal 0, goal.reload.progress_percent
    assert battle.reload.completed?

    follow_redirect!
    assert_match(/Is .*Project.* finished/i, response.body)

    post project_completions_path, params: { project_id: project.id, decision: "done" }
    assert_equal 100, goal.reload.progress_percent
    assert project.reload.completed?
  end

  test "project with battles keeps add-another-battle option" do
    goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Goal", position: 0
    )
    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: goal, horizon: "plan", title: "Plan", position: 0
    )
    project = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project", title: "Project", position: 0
    )
    @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: project, horizon: "day",
      title: "First battle", scheduled_on: Date.current, position: 0
    )

    get life_journey_path(@journey, focus_id: project.id)
    assert_response :success
    assert_match(/Your mountain is ready/i, response.body)
    assert_select "button.lp-strategy-next__secondary", text: /Add another battle/i
    assert_select "#add-another-battle input[name=horizon][value=day]"
    assert_select "#add-battle-title"
    assert_select "#strategy-add-battle.lp-strategy-add input[name=title]"
    assert_select "a.lp-strategy__board-add-link[href='#strategy-add-battle']"

    post strategy_goals_path, params: {
      life_area_id: @area.id, life_journey_id: @journey.id,
      parent_id: project.id, horizon: "day", scheduled_on: Date.current.to_s,
      title: "Second battle"
    }
    assert_equal 2, project.children.for_kind("day").count
    assert @user.daily_todos.for_day(Date.current).exists?(title: "Second battle")
  end

  test "strategy board shows visible add cards for plans projects and battles" do
    goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Goal", position: 0
    )
    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: goal, horizon: "plan", title: "Plan A", position: 0
    )
    project = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project", title: "Project A", position: 0
    )
    @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: project, horizon: "day",
      title: "Battle A", scheduled_on: Date.current, position: 0
    )

    get life_journey_path(@journey, focus_id: goal.id)
    assert_response :success
    assert_select "#strategy-add-plan.lp-strategy-add", text: /Add another plan/i
    assert_select "a.lp-strategy__board-add-link[href='#strategy-add-plan']", text: /Add plan/i
    assert_select "details.lp-strategy__optional", count: 0

    get life_journey_path(@journey, focus_id: plan.id)
    assert_response :success
    assert_select "#strategy-add-project.lp-strategy-add", text: /Add another project/i
    assert_select "a.lp-strategy__board-add-link[href='#strategy-add-project']", text: /Add project/i

    get life_journey_path(@journey, focus_id: project.id)
    assert_response :success
    assert_select "#strategy-add-battle.lp-strategy-add", text: /Add another battle/i
    assert_match(/Add today.?s battle/i, response.body)
  end

  test "strategy board shows sibling switcher when multiple plans or projects exist" do
    goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Goal", position: 0
    )
    plan_a = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: goal, horizon: "plan", title: "Plan Alpha", position: 0
    )
    plan_b = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: goal, horizon: "plan", title: "Plan Beta", position: 1
    )
    project_a = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan_a, horizon: "project", title: "Project One", position: 0
    )
    project_b = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan_a, horizon: "project", title: "Project Two", position: 1
    )
    @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: project_a, horizon: "day",
      title: "Battle One", scheduled_on: Date.current, position: 0
    )

    get life_journey_path(@journey, focus_id: plan_a.id)
    assert_response :success
    assert_select ".lp-strategy-siblings.is-plan", text: /Switch plan/i
    assert_select ".lp-strategy-siblings__chip.is-current", text: /Plan Alpha/i
    assert_select "a.lp-strategy-siblings__chip[href=?]", life_journey_path(@journey, focus_id: plan_b.id), text: /Plan Beta/i

    get life_journey_path(@journey, focus_id: project_a.id)
    assert_response :success
    assert_select ".lp-strategy-siblings.is-project", text: /Switch project/i
    assert_select ".lp-strategy-siblings__chip.is-current", text: /Project One/i
    assert_select "a.lp-strategy-siblings__chip[href=?]", life_journey_path(@journey, focus_id: project_b.id), text: /Project Two/i

    solo_project = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan_b, horizon: "project", title: "Lone Project", position: 0
    )
    get life_journey_path(@journey, focus_id: solo_project.id)
    assert_response :success
    assert_select ".lp-strategy-siblings", count: 0
  end

  test "strategy overflow shows rename and remove for goals plans projects and battles" do
    goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Goal", position: 0
    )
    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: goal, horizon: "plan", title: "Plan", position: 0
    )
    project = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project", title: "Project", position: 0
    )
    battle = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: project, horizon: "day",
      title: "Battle", scheduled_on: Date.current, position: 0
    )

    get life_journey_path(@journey, focus_id: goal.id)
    assert_response :success
    assert_select "#strategy-rename-#{goal.id}[value=?]", "Goal"
    assert_select "#strategy-rename-#{plan.id}[value=?]", "Plan"
    assert_select ".lp-strategy-overflow__action.is-save", minimum: 1
    assert_select ".lp-strategy-overflow__action.is-remove", minimum: 1

    get life_journey_path(@journey, focus_id: project.id)
    assert_response :success
    assert_select "#strategy-rename-#{battle.id}[value=?]", "Battle"
  end

  test "update renames strategy goals and syncs battle titles to today" do
    goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Old Goal", position: 0
    )
    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: goal, horizon: "plan", title: "Old Plan", position: 0
    )
    project = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project", title: "Old Project", position: 0
    )
    battle = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: project, horizon: "day",
      title: "Old Battle", scheduled_on: Date.current, position: 0
    )
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)
    assert @user.daily_todos.for_day(Date.current).exists?(title: "Old Battle", strategy_goal_id: battle.id)

    patch strategy_goal_path(goal), params: { title: "New Goal" }
    assert_redirected_to life_journey_path(@journey, focus_id: goal.id)
    assert_equal "New Goal", goal.reload.title
    assert_match(/Renamed/i, flash[:notice].to_s)

    patch strategy_goal_path(plan), params: { title: "New Plan" }
    assert_equal "New Plan", plan.reload.title

    patch strategy_goal_path(project), params: { title: "New Project" }
    assert_equal "New Project", project.reload.title

    patch strategy_goal_path(battle), params: { title: "New Battle" }
    assert_equal "New Battle", battle.reload.title
    assert @user.daily_todos.for_day(Date.current).exists?(title: "New Battle", strategy_goal_id: battle.id)

    patch strategy_goal_path(plan), params: { title: "   " }
    assert_equal "New Plan", plan.reload.title
    assert_match(/blank|can't be blank|Title/i, flash[:alert].to_s)
  end

  test "dashboard shows action points and strategy points" do
    goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Become ready", position: 0
    )
    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: goal, horizon: "plan", title: "Build skills", position: 0
    )
    project = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project", title: "Ship portfolio", position: 0
    )
    @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: project, horizon: "day",
      title: "Write one test", scheduled_on: Date.current, position: 0
    )

    get dashboard_path
    assert_response :success
    assert_match(/Action Points/i, response.body)
    assert_match(/Strategy Points/i, response.body)
  end
end
