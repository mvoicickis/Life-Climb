require "test_helper"

class DailyBattlePlanTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    Onboarding::Run.call(
      user: @user,
      area_key: "money",
      title: "Financial freedom",
      ideal_scene: "Calm savings and no money stress.",
      current_reality: "Building a budget habit.",
      next_win: "Launch Beta",
      today_mission: "Review my budget",
      closer_percent: 36
    )
  end

  test "home shows compressed Today timeline shell" do
    get dashboard_path
    assert_response :success
    assert_match(/Today/i, response.body)
    assert_no_match(/>\s*Strategy Points\s*</i, response.body)
    assert_select ".lp-dash-cta", count: 0
    assert_select "form[action=?]", battle_completion_path, count: 0
    assert_match(/lp-dash-nav/i, response.body)
    assert_select ".lp-dash-hero", count: 1
    assert_select ".lp-dash-timeline, .lp-dash-route, #first-climb-coach", minimum: 1
    assert_select ".lp-dash-project", count: 0
    assert_no_match(/Life Tree|Open Life/i, response.body)
    assert_no_match(/Daily Battle Plan/i, response.body)
    assert_no_match(/>\s*SP\s*</, response.body)
  end

  test "hero shows day percent track when strategy goal present" do
    journey = @user.primary_focused_journey
    area = journey.life_area
    @user.strategy_goals.create!(
      life_area: area, life_journey: journey, horizon: "goal",
      title: "Become debt-free", position: 0
    )

    get dashboard_path
    assert_response :success
    assert_select ".lp-dash-hero", count: 1
    assert_select ".lp-dash-hero__segs", count: 1
  end

  test "completing a battle checkbox asks project check without moving mountain percent" do
    journey = @user.primary_focused_journey
    area = journey.life_area
    goal = @user.strategy_goals.create!(
      life_area: area, life_journey: journey, horizon: "goal", title: "Become debt-free", position: 0
    )
    plan = @user.strategy_goals.create!(
      life_area: area, life_journey: journey, parent: goal, horizon: "plan", title: "Kill debt", position: 0
    )
    project = @user.strategy_goals.create!(
      life_area: area, life_journey: journey, parent: plan, horizon: "project", title: "Cut spend", position: 0
    )
    project_leaf = practice_leaf_for!(project)
    battle = @user.strategy_goals.create!(
      life_area: area, life_journey: journey, parent: project_leaf, horizon: "day",
      title: "Cancel subscription", scheduled_on: Date.current, position: 0
    )
    project_leaf = practice_leaf_for!(project)
    @user.strategy_goals.create!(
      life_area: area, life_journey: journey, parent: project_leaf, horizon: "day",
      title: "Call bank tomorrow", scheduled_on: Date.current + 1.day, position: 0
    )
    Strategy::CascadeToDaily.call(user: @user, life_area: area)
    todo = @user.daily_todos.for_day.find_by!(strategy_goal_id: battle.id)

    assert_equal 0, goal.progress_percent
    post complete_daily_todo_path(todo)
    assert_redirected_to dashboard_path
    follow_redirect!

    assert battle.reload.completed?
    assert_equal 0, goal.reload.progress_percent
    assert_match(/Is .*Steps.* finished/i, response.body)
    assert_match(/Yes, project done/i, response.body)

    post project_completions_url, params: { project_id: project_leaf.id, decision: "done" }
    assert_redirected_to dashboard_path
    post project_completions_url, params: { project_id: project.id, decision: "done" }
    assert_redirected_to dashboard_path
    follow_redirect!

    assert project_leaf.reload.completed?
    assert project.reload.completed?
    assert_equal 100, goal.reload.progress_percent
    assert_match(/Mountain now 100%/i, flash[:notice].to_s + response.body)
  end

  test "today does not offer freeform battle creation" do
    get dashboard_path
    assert_response :success
    assert_select "form.lp-dash-add", count: 0
    assert_no_match(/lp-dash-add/i, response.body)

    post daily_todos_url, params: {
      daily_todo: { title: "Cancel unused subscription", aspect_key: "money" }
    }
    assert_redirected_to life_journey_path(@user.primary_focused_journey)
    assert_match(/Plan new battles on Mountain/i, flash[:alert].to_s)
    assert_nil @user.daily_todos.for_day.find_by(title: "Cancel unused subscription")
  end

  test "checkbox completes open mission and todos with light juice" do
    todo = @user.daily_todos.create!(
      title: "Track spending",
      aspect_key: "money",
      scheduled_on: Date.current
    )
    mission = @user.missions.for_day.primary.incomplete.order(:id).first
    assert mission

    before = @user.reload.total_points
    post complete_daily_todo_path(todo)
    assert_redirected_to dashboard_path
    assert_operator flash[:ap_gained].to_i, :>, 0
    assert flash[:battle_celebrate].present?
    assert_nil flash[:climb_reward], "first ordinary checkbox is not a Climb Reward moment"

    post mission_completion_path(mission), params: { aspect_key: "money" }
    assert_redirected_to dashboard_path
    assert_operator flash[:ap_gained].to_i, :>, 0
    assert flash[:battle_celebrate].present?
    # A later win in the same day may hit a personal-best milestone — that's reserved.

    follow_redirect!
    assert @user.daily_todos.for_day.incomplete.none?
    assert mission.reload.completed?
    assert_operator @user.reload.total_points, :>, before
    assert_select ".lp-dash.is-battle-won", count: 1
    assert_select ".lp-dash-battle__won", count: 0
    assert_select "form[action=?]", battle_completion_path, count: 0
  end

  test "today lists strategy-fed battles without an add form" do
    titles = [
      "Finish Dashboard UI",
      "Workout",
      "Read Ruby",
      "Go on date",
      "Plan tomorrow"
    ]

    titles.each_with_index do |title, i|
      @user.daily_todos.create!(
        title: title,
        aspect_key: "money",
        scheduled_on: Date.current,
        position: i
      )
    end

    assert_equal 5, @user.daily_todos.for_day.count

    get dashboard_path
    assert_response :success
    titles.each { |title| assert_match(/#{Regexp.escape(title)}/i, response.body) }
    assert_select "form.lp-dash-add", count: 0
    assert_select ".lp-dash-tcard__win", minimum: 5
    assert_select "form[action=?]", battle_completion_path, count: 0
    # Per-item AP chips remain; batch reward footer is gone.
    assert_match(/#{GameRules::BATTLE_TODO_LP}\s*AP/, response.body)
  end
end
