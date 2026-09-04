# frozen_string_literal: true

require "test_helper"

class StrategyGoalsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    allow_extra_climbs!(@user)
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

  test "journey show is a cinematic RPG mountain with create-goal climb" do
    get life_journey_path(@journey)
    assert_response :success
    assert_match(/My Mountain/i, response.body)
    assert_match(/One mountain\. Today.?s battle/i, response.body)
    assert_match(/Name your mountain|New Destination/i, response.body)
    assert_select ".lp-rpg"
    assert_select ".lp-rpg__stage-sections"
    assert_select "[data-controller*='strategy-celebrate']"
    assert_select "[data-controller*='strategy-rpg']"
    assert_select "#strategy-camp-notebook", count: 0
    assert_select ".lp-strategy__board", count: 0
    assert_no_match(/Today.?s Focus/i, response.body)
  end

  test "creates a path project with trail coords" do
    post strategy_goals_path, params: {
      life_area_id: @area.id, life_journey_id: @journey.id,
      horizon: "goal", title: "Trail goal"
    }
    goal = @user.strategy_goals.for_kind("goal").last
    post strategy_goals_path, params: {
      life_area_id: @area.id, life_journey_id: @journey.id,
      parent_id: goal.id, horizon: "plan", title: "Main trail"
    }
    plan = @user.strategy_goals.for_kind("plan").last

    assert_difference -> { plan.children.for_kind("project").count }, 1 do
      post strategy_goals_path, params: {
        life_area_id: @area.id,
        life_journey_id: @journey.id,
        parent_id: plan.id,
        horizon: "project",
        title: "Planted camp",
        trail_x: 0.45,
        trail_y: 0.62,
        color_key: "teal"
      }, as: :turbo_stream
    end

    camp = plan.children.for_kind("project").find_by!(title: "Planted camp")
    expected = MountainTrailHelper::AutoSlot.snap(0.45, 0.62)
    assert_in_delta expected[:trail_x], camp.trail_x, 0.0001
    assert_in_delta expected[:trail_y], camp.trail_y, 0.0001
    assert_equal "teal", camp.color_key
  end

  test "creating a project without trail coords assigns an auto slot" do
    post strategy_goals_path, params: {
      life_area_id: @area.id, life_journey_id: @journey.id,
      horizon: "goal", title: "Auto pin goal"
    }
    goal = @user.strategy_goals.for_kind("goal").last
    post strategy_goals_path, params: {
      life_area_id: @area.id, life_journey_id: @journey.id,
      parent_id: goal.id, horizon: "plan", title: "Auto pin path"
    }
    plan = @user.strategy_goals.for_kind("plan").last

    post strategy_goals_path, params: {
      life_area_id: @area.id,
      life_journey_id: @journey.id,
      parent_id: plan.id,
      horizon: "project",
      title: "Unplanted camp"
    }
    camp = plan.children.for_kind("project").find_by!(title: "Unplanted camp")
    expected = MountainTrailHelper::AutoSlot.call(index: 0, total: 1)
    assert_in_delta expected[:trail_x], camp.trail_x, 0.0001
    assert_in_delta expected[:trail_y], camp.trail_y, 0.0001
  end

  test "goal defaults due_on to one year from today and awards goal SP" do
    post strategy_goals_path, params: {
      life_area_id: @area.id,
      life_journey_id: @journey.id,
      horizon: "goal",
      title: "Become a Rails developer"
    }
    goal = @user.strategy_goals.for_kind("goal").last
    assert_equal Strategy::YearCycle.default_goal_due, goal.due_on
    assert_equal 100, @user.reload.strategy_points
    assert_match(/Goal locked|Goal created/i, flash[:notice].to_s)
    assert_equal 100, flash[:sp_gained].to_i

    get life_journey_path(@journey)
    assert_response :success
    assert_select ".lp-trail-destination"
    assert_select "#mountain-trail"
    assert_select "#first-climb-coach", count: 0
    assert_select ".lp-strategy-mountain", count: 0
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
    assert_select ".lp-rpg"
    assert_select "#climb-path-project-#{project.id} .lp-climb-path__title", text: /Learn German/i
    assert_select ".lp-climb-path__quests", count: 0
    assert_select ".lp-rpg-sheet.is-quest-space", count: 0
    assert_select "#strategy-camp-notebook", count: 0
    assert_no_match(/Today.?s Focus/i, response.body)
    assert_no_match(/Monthly Goals/i, response.body)

    get objectives_strategy_goal_path(project)
    assert_response :success
    assert_select ".lp-climb-path__quest-title", text: /Learn German/i
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
    assert_redirected_to life_journey_path(@journey, peek: 1)
    assert_match(/Unknown strategy step/i, flash[:alert].to_s)
    assert_equal 0, @user.strategy_goals.where(horizon: "month").count
  end

  test "seed_win creates and wins a battle in one post" do
    goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Goal", position: 0
    )
    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: goal, horizon: "plan", title: "Plan", position: 0
    )
    project = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project", title: "Empty camp", position: 0
    )

    assert_difference -> { @user.reload.life_points }, GameRules::BATTLE_TODO_LP do
      post strategy_goals_path, params: {
        life_area_id: @area.id,
        life_journey_id: @journey.id,
        parent_id: project.id,
        horizon: "day",
        scheduled_on: Date.current.to_s,
        title: "Take the first small step",
        seed_win: "1"
      }, as: :turbo_stream
    end

    assert_response :ok
    battle = project.children.for_kind("day").find_by!(title: "Take the first small step")
    assert battle.completed?
    todo = @user.daily_todos.for_day.find_by!(strategy_goal_id: battle.id)
    assert todo.completed?
    assert_match "trail-battles-#{project.id}", response.body
    assert_no_match "trail-battle-suggestion-#{project.id}", response.body
  end

  test "create day battle without seed_win stays open" do
    goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Goal", position: 0
    )
    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: goal, horizon: "plan", title: "Plan", position: 0
    )
    project = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project", title: "Empty camp", position: 0
    )

    post strategy_goals_path, params: {
      life_area_id: @area.id,
      life_journey_id: @journey.id,
      parent_id: project.id,
      horizon: "day",
      scheduled_on: Date.current.to_s,
      title: "Custom battle"
    }, as: :turbo_stream

    assert_response :ok
    battle = project.children.for_kind("day").find_by!(title: "Custom battle")
    assert_not battle.completed?
    todo = @user.daily_todos.for_day.find_by!(strategy_goal_id: battle.id)
    assert_nil todo.completed_at
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
    project_leaf = practice_leaf_for!(project)
    battle = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: project_leaf, horizon: "day",
      title: "Direct battle", scheduled_on: Date.current, position: 0
    )
    assert battle.persisted?
    assert_equal project_leaf.id, battle.parent_id
  end

  test "adding a second battle at top keeps position non-negative" do
    goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Goal", position: 0
    )
    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: goal, horizon: "plan", title: "Plan", position: 0
    )
    project = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project", title: "Camp", position: 0
    )

    assert_difference -> { project.children.for_kind("day").count }, 1 do
      post strategy_goals_path, params: {
        life_area_id: @area.id,
        life_journey_id: @journey.id,
        parent_id: project.id,
        horizon: "day",
        scheduled_on: Date.current.to_s,
        add_position: "top",
        title: "First battle"
      }
    end
    first = project.children.for_kind("day").find_by!(title: "First battle")
    assert_equal 0, first.position

    assert_difference -> { project.children.for_kind("day").count }, 1 do
      post strategy_goals_path, params: {
        life_area_id: @area.id,
        life_journey_id: @journey.id,
        parent_id: project.id,
        horizon: "day",
        scheduled_on: Date.current.to_s,
        add_position: "top",
        title: "Second battle"
      }
    end
    second = project.children.for_kind("day").find_by!(title: "Second battle")
    assert_equal 0, second.position, "newest battle should sit at the top"
    assert_equal 1, first.reload.position, "older battle should shift down"
    assert_operator second.position, :>=, 0
    assert_operator first.position, :>=, 0
  end

  test "adding a battle via turbo stream stays on camp sheet battles list" do
    goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Goal", position: 0
    )
    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: goal, horizon: "plan", title: "Plan", position: 0
    )
    project = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project", title: "Camp", position: 0
    )

    assert_difference -> { project.children.for_kind("day").count }, 1 do
      post strategy_goals_path, params: {
        life_area_id: @area.id,
        life_journey_id: @journey.id,
        parent_id: project.id,
        horizon: "day",
        scheduled_on: Date.current.to_s,
        add_position: "top",
        title: "Stay in sheet battle"
      }, as: :turbo_stream
    end

    assert_equal Mime[:turbo_stream].to_s, response.media_type
    assert_includes response.body, "turbo-stream"
    assert_includes response.body, "trail-battles-#{project.id}"
    assert_includes response.body, "Stay in sheet battle"
    assert_no_match(%r{href=["']/life_journeys/}, response.body)
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
    project_leaf = practice_leaf_for!(project)
    battle = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: project_leaf, horizon: "day",
      title: "Win this", scheduled_on: Date.current, position: 0
    )
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)
    todo = @user.daily_todos.find_by!(strategy_goal_id: battle.id)

    assert_equal 0, goal.progress_percent
    post complete_daily_todo_path(todo)
    assert_equal 0, goal.reload.progress_percent
    assert battle.reload.completed?

    follow_redirect!
    assert battle.reload.completed?
    assert_equal 0, goal.reload.progress_percent
    assert Strategy::ProjectCheckQueue.next_for(user: @user, session: session).present?

    post project_completions_path, params: { project_id: project_leaf.id, decision: "done" }
    assert project_leaf.reload.completed?
    post project_completions_path, params: { project_id: project.id, decision: "done" }
    assert_equal 100, goal.reload.progress_percent
    assert project.reload.completed?
  end

  test "rpg mountain shows trail checkpoints missions and battles for focused project" do
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
    @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan_a, horizon: "project", title: "Project Two", position: 1
    )
    battle = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: project_a, horizon: "day",
      title: "Battle One", scheduled_on: Date.current, position: 0
    )
    @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan_b, horizon: "project", title: "Lone Project", position: 0
    )

    get life_journey_path(@journey, focus_id: project_a.id)
    assert_response :success
    assert_select ".lp-rpg.is-v4-phone"
    assert_select "#mountain-trail.lp-trail.is-v4"
    assert_select "#trail-camps"
    assert_select ".lp-trail__peak-title", text: /Goal/i
    assert_select ".lp-trail-hud__plan", text: /Plan Alpha/i
    assert_select ".lp-trail-hud__plan", text: /Plan Beta/i
    assert_select ".lp-trail-hud__plan.is-active", text: /Plan Alpha/i
    assert_select "#trail-camp-#{project_a.id}[aria-label=?]", "Project One"
    assert_select ".lp-climb-path__quests", count: 0
    assert_select ".lp-rpg-stats", count: 0
    assert_select ".lp-rpg-path", count: 0
    assert_select ".lp-dash-nav.is-v4 .lp-dash-nav__link.is-active", text: /Mountain/i
    assert_select "#strategy-camp-notebook", count: 0
    assert_select "[data-controller*=strategy-rpg]"
    # Battle win lives in the trail camp sheet (not a separate quest board).
    assert_select "#trail-sheet-camp-#{project_a.id} form[action=?]", battle_win_path(battle)
    assert_select ".lp-rpg-camp-folder__cta", count: 0
  end

  test "focusing a plan lights that path and shows its section cards" do
    goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Goal", position: 0
    )
    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: goal, horizon: "plan", title: "Plan", position: 0
    )
    project = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project", title: "Auth Mission", position: 0
    )

    get life_journey_path(@journey, focus_id: plan.id)
    assert_response :success
    assert_select ".lp-rpg.is-v4-phone"
    assert_select ".lp-trail__peak-title", text: /Goal/i
    assert_select "#trail-camp-#{project.id}[aria-label=?]", "Auth Mission"
    assert_select ".lp-dash-nav__fab"
    assert_select ".lp-trail-plant"
    assert_select "#rpg-add-checkpoint", count: 0
  end

  test "completed camps leave the mountain photo" do
    goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Goal", position: 0
    )
    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: goal, horizon: "plan", title: "Done Plan", position: 0
    )
    project = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project", title: "Done Project", position: 0
    )
    project_leaf = practice_leaf_for!(project)
    battle = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: project_leaf, horizon: "day",
      title: "Done Battle", scheduled_on: Date.current, position: 0
    )
    battle.complete!
    project.complete!
    plan.complete!

    get life_journey_path(@journey, focus_id: plan.id)
    assert_response :success
    assert_select ".lp-rpg.is-v4-phone"
    assert_select "#trail-camp-#{project.id}", count: 0
    assert_select ".lp-trail__peak-title", text: /Goal/i
  end

  test "sections carousel lists path-level camps under the selected plan" do
    goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Goal", position: 0
    )
    plan_a = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: goal, horizon: "plan", title: "Main Plan", position: 0
    )
    3.times do |i|
      @user.strategy_goals.create!(
        life_area: @area, life_journey: @journey, parent: goal, horizon: "plan", title: "Side Plan #{i}", position: i + 1
      )
    end
    projects = 4.times.map do |i|
      @user.strategy_goals.create!(
        life_area: @area, life_journey: @journey, parent: plan_a, horizon: "project", title: "Project #{i}", position: i
      )
    end
    projects_first_leaf = practice_leaf_for!(projects.first)
    @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: projects_first_leaf, horizon: "day",
      title: "Battle Focus", scheduled_on: Date.current, position: 0
    )

    get life_journey_path(@journey, focus_id: projects_first_leaf.id)
    assert_response :success
    assert_select ".lp-trail-hud__plan.is-active", text: /Main Plan/i
    assert_select "#trail-camp-#{projects.first.id}[aria-label=?]", "Project 0"
    assert_select "#trail-camps .lp-trail-camp", minimum: 3
    assert_select ".lp-climb-path__quests", count: 0
    assert_select "#strategy-camp-notebook", count: 0
  end

  test "focus surface exposes quiet add path checkpoint and quest detail" do
    goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Goal", position: 0
    )
    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: goal, horizon: "plan", title: "Plan", position: 0
    )
    project = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project", title: "Project", position: 0
    )
    project_leaf = practice_leaf_for!(project)
    @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: project_leaf, horizon: "day",
      title: "Battle", scheduled_on: Date.current, position: 0
    )

    get life_journey_path(@journey, focus_id: project_leaf.id)
    assert_response :success
    assert_select ".lp-rpg.is-v4-phone"
    assert_select ".lp-dash-nav__fab"
    assert_select ".lp-trail-plant"
    assert_select "#trail-camp-#{project.id}[aria-label=?]", "Project"
    assert_select "#rpg-add-checkpoint", count: 0
    assert_select ".lp-climb-path__quests", count: 0
    assert_select ".lp-rpg-practice-add", text: /Prepare New Quest/i, count: 0
    # One Plan per journey: the "+ Add path" entry is gone from the rail.
    assert_select "a.lp-rpg-add.is-path.is-guide-entry[href=?]", companion_guide_path(new_plan: 1), count: 0

    get objectives_strategy_goal_path(project)
    assert_response :success
    assert_select ".lp-climb-path__quest-title"
    assert_select ".lp-climb-path__quest-add-input"
  end

  test "tapping a plan focuses missions under that checkpoint" do
    goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Goal", position: 0
    )
    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: goal, horizon: "plan", title: "Find a Job", position: 0
    )
    other_plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: goal, horizon: "plan", title: "Build SaaS", position: 1
    )

    get life_journey_path(@journey, focus_id: plan.id)
    assert_response :success
    assert_select ".lp-trail-hud__plan.is-active", text: /Find a Job/i
    assert_select ".lp-trail-hud__plan", text: /Build SaaS/i

    post strategy_goals_path, params: {
      life_area_id: @area.id,
      life_journey_id: @journey.id,
      parent_id: plan.id,
      horizon: "project",
      title: "Improve Resume"
    }
    project = @user.strategy_goals.for_kind("project").find_by!(title: "Improve Resume")
    assert_equal plan.id, project.parent_id
    assert_not_equal other_plan.id, project.parent_id
    assert_redirected_to life_journey_path(@journey, goal_id: goal.id, plan_id: plan.id, focus_id: project.id)
  end

  test "deleting a checkpoint returns to a sibling camp on the same path" do
    goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Goal", position: 0
    )
    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: goal, horizon: "plan", title: "Main path", position: 0
    )
    keep = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project", title: "Keep me", position: 0
    )
    junk = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project", title: "wewe", position: 1
    )

    delete strategy_goal_path(junk)
    assert_redirected_to life_journey_path(@journey, goal_id: goal.id, plan_id: plan.id, focus_id: keep.id)
    assert_not @user.strategy_goals.exists?(id: junk.id)

    follow_redirect!
    assert_select "#climb-path-project-#{keep.id} .lp-climb-path__title", text: /Keep me/
    assert_select ".lp-climb-path__node", text: /wewe/, count: 0
  end

  test "creating a checkpoint redirects with goal plan and focus so it stays visible" do
    goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Goal", position: 0
    )
    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: goal, horizon: "plan", title: "Main path", position: 0
    )
    current = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project", title: "First camp", position: 0
    )
    current_leaf = practice_leaf_for!(current)
    current_leaf.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Step one", scheduled_on: Date.current, position: 0
    )

    post strategy_goals_path, params: {
      life_area_id: @area.id,
      life_journey_id: @journey.id,
      parent_id: plan.id,
      horizon: "project",
      title: "Launch prep"
    }
    created = @user.strategy_goals.for_kind("project").find_by!(title: "Launch prep")
    assert_redirected_to life_journey_path(@journey, goal_id: goal.id, plan_id: plan.id, focus_id: created.id)

    follow_redirect!
    assert_response :success
    assert_select "#climb-path-project-#{created.id} .lp-climb-path__title", text: /Launch prep/
    assert_select ".lp-rpg-section-head", count: 0
    assert_select ".lp-rpg-practice-cats__hint", count: 0
    assert_select ".lp-rpg-practice-focus.is-entered", count: 0
    assert_match(/Checkpoint added|Launch prep/i, flash[:notice].to_s + response.body)
  end

  test "day schedule toggle plans practice for today via scheduled_on" do
    goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Goal", position: 0
    )
    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: goal, horizon: "plan", title: "Plan", position: 0
    )
    project = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project", title: "Vocabulary", position: 0
    )
    project_leaf = practice_leaf_for!(project)
    battle = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: project_leaf, horizon: "day",
      title: "Flashcards", scheduled_on: Date.current + 1.day, position: 0
    )

    patch strategy_goal_path(battle), params: { scheduled_on: Date.current.to_s }
    assert_redirected_to life_journey_path(@journey, goal_id: goal.id, plan_id: plan.id, focus_id: project_leaf.id)
    assert_equal Date.current, battle.reload.scheduled_on
    assert_nil flash[:notice]

    patch strategy_goal_path(battle), params: { scheduled_on: "later" }
    assert_redirected_to life_journey_path(@journey, goal_id: goal.id, plan_id: plan.id, focus_id: project_leaf.id)
    assert_equal Date.current + 1.day, battle.reload.scheduled_on
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
    project_leaf = practice_leaf_for!(project)
    battle = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: project_leaf, horizon: "day",
      title: "Old Battle", scheduled_on: Date.current, position: 0
    )
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)
    assert @user.daily_todos.for_day(Date.current).exists?(title: "Old Battle", strategy_goal_id: battle.id)

    patch strategy_goal_path(goal), params: { title: "New Goal" }
    assert_redirected_to life_journey_path(@journey, goal_id: goal.id)
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

  test "update persists description on goal and project rows" do
    goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Summit", position: 0
    )
    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: goal, horizon: "plan", title: "Path", position: 0
    )
    project = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project", title: "Camp", position: 0
    )

    patch strategy_goal_path(goal), params: { description: "Reach the peak" }
    assert_equal "Reach the peak", goal.reload.description

    patch strategy_goal_path(project), params: { description: "Daily strength work" }
    assert_equal "Daily strength work", project.reload.description

    patch strategy_goal_path(project), params: { description: "   " }
    assert_nil project.reload.description
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
    project_leaf = practice_leaf_for!(project)
    @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: project_leaf, horizon: "day",
      title: "Write one test", scheduled_on: Date.current, position: 0
    )

    get dashboard_path
    assert_response :success
    assert_today_v2_shell!
    assert_no_match(/>\s*Strategy Points\s*</i, response.body)
  end

  test "missing life journey redirects instead of 404" do
    get life_journey_path(id: 9_999_999)
    assert_redirected_to life_journey_path(@journey)
    assert_match(/isn.?t here anymore/i, flash[:alert].to_s)

    @journey.destroy!
    get life_journey_path(id: 9_999_999)
    assert_redirected_to new_life_journey_path
  end

  test "journey page still renders after strategy mountain ships" do
    get life_points_path
    assert_response :success
    assert_match(/Stats/i, response.body)
    assert_select ".lp-dash-nav.is-v4"
    assert_select ".lp-dash-nav__link.is-active", text: /Stats/i
    assert_select ".lp-dash-nav__fab", count: 0
  end

  test "creating a daily practice persists repeat on the model" do
    goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Goal", position: 0
    )
    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: goal, horizon: "plan", title: "Plan", position: 0
    )
    project = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project", title: "Lessons", position: 0
    )
    nested = practice_leaf_for!(project)

    post strategy_goals_path, params: {
      life_area_id: @area.id, life_journey_id: @journey.id,
      parent_id: nested.id, horizon: "day", scheduled_on: Date.current.to_s,
      title: "Do lessons", repeat: "daily"
    }
    practice = @user.strategy_goals.for_kind("day").find_by!(title: "Do lessons")
    assert practice.repeat_daily?
    assert_redirected_to life_journey_path(@journey, goal_id: goal.id, plan_id: plan.id, focus_id: nested.id)

    follow_redirect!
    assert_response :success
    assert_select ".lp-climb-path__quests", count: 0

    get objectives_strategy_goal_path(nested)
    assert_response :success
    assert_select ".lp-climb-path__quest-title"
    assert_select ".lp-rpg-practice-folder__title", count: 0
  end

  test "completing a daily practice rolls the template to tomorrow" do
    goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Goal", position: 0
    )
    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: goal, horizon: "plan", title: "Plan", position: 0
    )
    project = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project", title: "Lessons", position: 0
    )
    project_leaf = practice_leaf_for!(project)
    practice = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: project_leaf, horizon: "day",
      title: "Do lessons", scheduled_on: Date.current, repeat: "daily", position: 0
    )
    Strategy::CascadeToDaily.call(user: @user, life_area: @area, from: Date.current, to: Date.current + 1.day)
    todo = @user.daily_todos.find_by!(strategy_goal_id: practice.id, scheduled_on: Date.current)

    post complete_daily_todo_path(todo)
    assert_redirected_to dashboard_path

    practice.reload
    assert practice.repeat_daily?
    assert_nil practice.completed_at
    assert_equal Date.current + 1.day, practice.scheduled_on
    assert todo.reload.completed?
    assert @user.daily_todos.exists?(strategy_goal_id: practice.id, scheduled_on: Date.current + 1.day)
  end

  test "update and destroy reject holding nodes" do
    goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Goal", position: 0
    )
    camp = Strategy::HoldingProject.ensure!(user: @user, journey: @journey)
    plan = camp.parent
    assert_equal goal.id, plan.parent_id

    patch strategy_goal_path(camp), params: { title: "Visible now" }
    assert_redirected_to %r{/}
    assert_equal I18n.t("strategy.holding.project_title"), camp.reload.title

    delete strategy_goal_path(camp)
    assert StrategyGoal.exists?(camp.id)

    patch strategy_goal_path(plan), params: { title: "Visible plan" }
    assert_equal I18n.t("strategy.holding.plan_title"), plan.reload.title

    delete strategy_goal_path(plan)
    assert StrategyGoal.exists?(plan.id)
  end

  test "open day battles can swap position with move" do
    goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Goal", position: 0
    )
    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: goal, horizon: "plan", title: "Plan", position: 0
    )
    project = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project", title: "Camp", position: 0
    )
    first = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: project, horizon: "day",
      title: "First", scheduled_on: Date.current, position: 0
    )
    second = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: project, horizon: "day",
      title: "Second", scheduled_on: Date.current, position: 1
    )

    patch strategy_goal_path(second), params: { move: "up" }
    assert_response :redirect
    assert_equal 0, second.reload.position
    assert_equal 1, first.reload.position

    patch strategy_goal_path(second), params: { move: "up" }
    assert_equal 0, second.reload.position
    assert_equal 1, first.reload.position
  end

  test "day battles can toggle daily and log-a-number from update" do
    goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Goal", position: 0
    )
    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: goal, horizon: "plan", title: "Plan", position: 0
    )
    project = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project", title: "Camp", position: 0
    )
    battle = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: project, horizon: "day",
      title: "Read", scheduled_on: Date.current, repeat: "daily", position: 0
    )

    patch strategy_goal_path(battle), params: { track_quantity: "1", quantity_kind: "up", unit: "pages" }
    battle.reload
    assert battle.quantified?
    assert_equal "pages", battle.unit

    patch strategy_goal_path(battle), params: { repeat: "none" }
    assert_not battle.reload.repeat_daily?

    patch strategy_goal_path(battle), params: { track_quantity: "0" }
    assert_not battle.reload.quantified?
  end
end
