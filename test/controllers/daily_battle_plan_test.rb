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

  test "home shows premium battle hierarchy" do
    get dashboard_path
    assert_response :success
    assert_match(/Today/i, response.body)
    assert_match(/Battle/i, response.body)
    assert_match(/Action Points/i, response.body)
    assert_no_match(/>\s*Strategy Points\s*</i, response.body)
    assert_select ".lp-dash-cta", text: /Complete Today/i
    assert_match(/battles ready/i, response.body)
    assert_match(/See your mountain/i, response.body)
    assert_match(/Review my budget/i, response.body)
    assert_match(/lp-dash-nav/i, response.body)
    assert_select ".lp-dash-climb", count: 1
    assert_select ".lp-dash-climb__label", text: /up the mountain/i
    assert_select ".lp-dash-battle", count: 1
    assert_select ".lp-dash-hero", count: 0
    assert_select ".lp-dash-plan"
    assert_select ".lp-dash-project", count: 0
    assert_no_match(/Life Tree|Open Life/i, response.body)
    assert_no_match(/Daily Battle Plan/i, response.body)
    assert_no_match(/\bAP\b/, response.body)
    assert_no_match(/>\s*SP\s*</, response.body)
  end

  test "climb band shows mountain percent when strategy goal present" do
    journey = @user.primary_focused_journey
    area = journey.life_area
    @user.strategy_goals.create!(
      life_area: area, life_journey: journey, horizon: "goal",
      title: "Become debt-free", position: 0
    )

    get dashboard_path
    assert_response :success
    assert_select ".lp-dash-climb", count: 1
    climber_style = css_select(".lp-dash-climb__climber").first["style"].to_s
    assert_match(/\Aleft:\s*(\d+)%\z/, climber_style)
    trail_pct = climber_style[/\d+/].to_i
    closer = css_select(".lp-dash-climb__pct").first.text.to_i
    assert_equal [ closer, 6 ].max, trail_pct, "climber should be inset at least 6% on the trail"
    assert_select ".lp-dash-bar__fill[style=?]", "width: #{closer}%"
    assert_select ".lp-dash-climb__rail-fill[style=?]", "width: #{closer}%"
    assert_select ".lp-dash-climb__pct", text: closer.to_s
    assert_select ".lp-dash-climb__label", text: /#{closer}%\s*up the mountain/i
    assert_select ".lp-dash-climb__rail", count: 1
    assert_select ".lp-dash-hero", count: 0
  end

  test "complete battle asks project check without moving mountain percent" do
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

    assert_equal 0, goal.progress_percent
    post battle_completion_url
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

  test "complete battle finishes open mission and todos" do
    @user.daily_todos.create!(
      title: "Track spending",
      aspect_key: "money",
      scheduled_on: Date.current
    )

    before = @user.reload.total_points
    post battle_completion_url
    assert_redirected_to dashboard_path
    follow_redirect!
    assert_match(/Battle complete/i, flash[:notice].to_s + response.body)

    assert @user.daily_todos.for_day.incomplete.none?
    mission = @user.missions.for_day.primary.order(:id).last
    assert mission.completed?
    assert_operator @user.reload.total_points, :>, before
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
    assert_match(/See your mountain/i, response.body)

    expected_reward = (5 * GameRules::BATTLE_TODO_LP) + @user.missions.for_day.primary.incomplete.first.lp_reward
    assert_match(/\+#{expected_reward}/, response.body)
  end
end
