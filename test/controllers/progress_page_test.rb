# frozen_string_literal: true

require "test_helper"

class ProgressPageTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    allow_extra_climbs!(@user)
    Onboarding::Run.call(
      user: @user,
      area_key: "money",
      title: "Financial freedom",
      ideal_scene: "Calm savings",
      current_reality: "Budgeting",
      next_win: "Emergency fund",
      today_mission: "Track spending",
      closer_percent: 25
    )
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
  end

  test "stats page renders hero points and activity" do
    get life_points_path
    assert_response :success
    assert_match(/Stats/i, response.body)
    assert_select ".lp-progress__subtitle", text: /moving/i
    assert_match(/Battle strength/i, response.body)
    assert_match(/Planning power/i, response.body)
    assert_match(/See weekly activity/i, response.body)
    assert_match(/Activity/i, response.body)
    assert_match(/7 Days/i, response.body)
    assert_match(/Weekly activity/i, response.body)
    assert_match(/Milestones/i, response.body)
    assert_match(/What changed/i, response.body)
    assert_select ".lp-progress-changed__delta.is-up", minimum: 0
    assert_select ".lp-progress-changed__delta.is-down", count: 0
    assert_select ".lp-progress-badge.is-locked"
    assert_select ".lp-progress-badge.is-glow"
    assert_no_match(/0 of/i, response.body)
    assert_no_match(/<h2>\s*Achievements\s*<\/h2>/i, response.body)
    assert_match(/lp-dash-nav/i, response.body)
    assert_select ".stats-hero"
    assert_select ".stats-hero__lead"
    assert_select ".stats-hero__meta"
    assert_select ".stats-hero__foot strong", text: /\d+%/
    assert_select ".lp-dash-nav__link", text: /Mountain/i
    assert_select ".lp-dash-nav__link", text: /Today/i
    assert_select ".lp-dash-nav__link", text: /You/i
    assert_select ".lp-dash-nav__link", text: /Habits/i, count: 0
    assert_select ".lp-dash-nav__link", text: /Stats/i
    assert_select ".lp-dash-nav__link.is-active", text: /Stats/i
    assert_select ".lp-dash-nav.is-v4"
    assert_select ".lp-dash-nav__fab", count: 0
    assert_no_match(/Climb progress/i, response.body)
    assert_no_match(/Mountain Summary/i, response.body)
    assert_no_match(/Your strength/i, response.body)
    assert_select ".lp-progress-donut__center span", text: /Action Points|AP/i
  end

  test "stats hero percent matches today when strategy goal exists" do
    goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Become debt-free", position: 0
    )
    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: goal, horizon: "plan", title: "Become Job Ready", position: 0
    )
    other_plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: goal, horizon: "plan", title: "Kill debt", position: 1
    )
    project = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project", title: "Portfolio", position: 0
    )
    @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: other_plan, horizon: "project", title: "Budget", position: 0
    )
    project.complete!
    Strategy::SyncCompletion.call(project: project)

    expected = goal.reload.progress_percent.to_i

    get dashboard_path
    assert_response :success
    assert_select ".lp-today-v2-header", count: 1
    assert_select ".lp-dash-hero__segs", count: 0

    get life_points_path
    assert_response :success
    assert_select ".stats-hero__foot strong", text: /#{expected}%/
    assert_match(/Become debt-free/i, response.body)
    assert_match(/Plans/i, response.body)
    assert_match(/Camps/i, response.body)
    assert_match(/Now:/i, response.body)
    assert_match(/Become Job Ready|Kill debt/i, response.body)
    assert_no_match(/\b#{@journey.closer_percent.round}%\b/, response.body) if @journey.closer_percent.round != expected
  end

  test "period query updates selected chip" do
    get life_points_path(period: "30d")
    assert_response :success
    assert_match(/period=30d.*is-active|is-active.*30 Days/i, response.body)
  end

  test "nav labels are mountain today you" do
    get life_points_path
    assert_select ".lp-dash-nav__link", text: /Today/i
    assert_select ".lp-dash-nav__link", text: /Mountain/i
    assert_select ".lp-dash-nav__link", text: /You/i
    assert_select ".lp-dash-nav__link", text: /Habits/i, count: 0
    assert_select ".lp-dash-nav__link", text: /Stats/i
    assert_select ".lp-dash-nav__link", text: /\A\s*Progress\s*\z/, count: 0
  end

  test "journey trends show battles section and omit empty quantified habits" do
    goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Season", position: 0
    )
    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: goal, horizon: "plan", title: "Path", position: 0
    )
    project = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project", title: "Camp", position: 0
    )
    day = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: project, horizon: "day",
      title: "Ship it", scheduled_on: Date.current, position: 0
    )
    @user.daily_todos.create!(
      title: "Ship it",
      aspect_key: @area.key,
      scheduled_on: Date.current,
      strategy_goal: day,
      completed_at: Time.current,
      position: 0
    )

    get life_points_path
    assert_response :success
    assert_match(/Your climb trends/i, response.body)
    assert_match(/Battles per week/i, response.body)
    assert_match(/More Battles this week than last|About the same as last week|A bit quieter than last week/i, response.body)
    assert_select ".lp-journey-trends"
    assert_select "[data-controller='journey-trends']"
    assert_select ".lp-journey-trends__camps", count: 1
    assert_select ".lp-journey-trends__habits", count: 0
    assert_select "canvas[data-journey-trends-target='camp']", count: 1
    assert_match(/See weekly activity/i, response.body)
    assert_match(/Weekly activity/i, response.body)
  end

  test "journey trends render quantified graphs and linked habit week" do
    enable_habits!
    goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Season", position: 0
    )
    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: goal, horizon: "plan", title: "Path", position: 0
    )
    pages = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project",
      title: "Read the book", position: 0, target_amount: 100, unit: "pages"
    )
    @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project",
      title: "Save cash", position: 1, target_amount: 500, unit: "€"
    )
    @user.strategy_quantity_logs.create!(
      strategy_goal: pages, amount: 12, unit: "pages", logged_on: Date.current
    )
    @user.habits.create!(
      name: "Linked stretch",
      points: 5,
      frequency: "daily",
      active: true,
      unit: "times",
      show_on_home: true,
      position: 1,
      stat_type: "growth",
      life_journey: @journey
    )
    pages_habit = @user.habits.create!(
      name: "Income",
      points: 5,
      frequency: "daily",
      active: true,
      unit: "€",
      show_on_home: true,
      position: 2,
      stat_type: "growth",
      life_journey: @journey
    )
    @user.daily_logs.create!(habit: pages_habit, logged_on: Date.current, amount: 45)
    @user.habits.create!(
      name: "Unlinked walk",
      points: 5,
      frequency: "daily",
      active: true,
      unit: "times",
      show_on_home: true,
      position: 3,
      stat_type: "growth"
    )

    get life_points_path
    assert_response :success
    assert_match(/Camp progress/i, response.body)
    assert_match(/Read the book/i, response.body)
    assert_match(/Save cash/i, response.body)
    assert_match(/Target 100 pages/i, response.body)
    assert_match(/Target 500 €/i, response.body)
    assert_select ".lp-camp-folder", count: 2
    assert_select ".lp-camp-toggle__btn", count: 3
    assert_select "canvas[data-journey-trends-target='camp']", count: 2
    assert_match(/Habits this week/i, response.body)
    assert_match(/Linked stretch/i, response.body)
    assert_match(/Income/i, response.body)
    assert_select ".lp-journey-habits__row", text: /Unlinked walk/i, count: 0
    assert_select ".lp-journey-habits__row", count: 2
    assert_select ".lp-journey-habits__row.is-quantity", count: 1
    assert_select ".lp-journey-habits__day", count: 14
    assert_select ".lp-journey-habits__amount", text: "45"
    assert_select ".lp-journey-habits__unit", text: "€"
  end

  test "journey stats section is not rendered" do
    enable_habits!
    @user.areas.create!(name: "Health", position: 1)

    get life_points_path
    assert_response :success
    assert_select ".lp-journey-stats", count: 0
    assert_no_match(/Your stats/i, response.body)
  end
end
