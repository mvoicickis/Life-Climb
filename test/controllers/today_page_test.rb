# frozen_string_literal: true

require "test_helper"

class TodayPageTest < ActionDispatch::IntegrationTest
  test "today renders for hierarchy-ready user with timeline header" do
    user = users(:one)
    sign_in_as user
    Onboarding::Run.call(
      user: user,
      area_key: "career",
      title: "Ship",
      ideal_scene: "Live",
      current_reality: "Building",
      next_win: "Launch",
      today_mission: "Write tests",
      closer_percent: 20
    )
    journey = user.reload.primary_focused_journey
    area = journey.life_area
    goal = user.strategy_goals.create!(life_area: area, life_journey: journey, horizon: "goal", title: "Goal", position: 0)
    plan = user.strategy_goals.create!(life_area: area, life_journey: journey, parent: goal, horizon: "plan", title: "Plan", position: 0)
    project = user.strategy_goals.create!(life_area: area, life_journey: journey, parent: plan, horizon: "project", title: "Project", position: 0)
    leaf = practice_leaf_for!(project)
    user.strategy_goals.create!(life_area: area, life_journey: journey, parent: leaf, horizon: "day", title: "Battle", scheduled_on: Date.current, position: 0)
    Strategy::CascadeToDaily.call(user: user, life_area: area)

    assert Strategy::HierarchyReady.call(user: user)
    get dashboard_path
    assert_response :success, -> { "body=#{response.body.to_s[0, 2000]}" }
    assert_select ".lp-dash-hero", count: 1
    assert_select ".lp-dash-timeline", count: 1
    assert_select ".lp-dash-tcard__title", text: "Battle"
  end

  test "Today hides the habits section, nag, and habit count while habits are disabled" do
    user = users(:one)
    sign_in_as user
    Onboarding::Run.call(
      user: user, area_key: "career", title: "Ship", ideal_scene: "Live",
      current_reality: "Building", next_win: "Launch", today_mission: "Write tests",
      closer_percent: 20
    )
    journey = user.reload.primary_focused_journey
    area = journey.life_area
    goal = user.strategy_goals.create!(life_area: area, life_journey: journey, horizon: "goal", title: "Goal", position: 0)
    plan = user.strategy_goals.create!(life_area: area, life_journey: journey, parent: goal, horizon: "plan", title: "Plan", position: 0)
    project = user.strategy_goals.create!(life_area: area, life_journey: journey, parent: plan, horizon: "project", title: "Project", position: 0)
    leaf = practice_leaf_for!(project)
    user.strategy_goals.create!(life_area: area, life_journey: journey, parent: leaf, horizon: "day", title: "Battle", scheduled_on: Date.current, position: 0)
    Strategy::CascadeToDaily.call(user: user, life_area: area)
    # A real habit exists but must be hidden, not merely absent.
    user.habits.create!(name: "Read", unit: "pages", points: 5, frequency: "daily",
      active: true, show_on_home: true, stat_type: "growth", goal: 10)

    get dashboard_path
    assert_response :success
    assert_select ".lp-dash-anytime", count: 0
    assert_no_match(/Add a habit/i, response.body)
    assert_no_match(/\d+\s+habits/i, response.body)
    assert_select ".lp-dash-hero__lab em", text: /battle/i
  end

  test "battle day strip renders above the habits section" do
    enable_habits!
    user = users(:one)
    sign_in_as user
    Onboarding::Run.call(
      user: user,
      area_key: "career",
      title: "Ship",
      ideal_scene: "Live",
      current_reality: "Building",
      next_win: "Launch",
      today_mission: "Write tests",
      closer_percent: 20
    )
    journey = user.reload.primary_focused_journey
    area = journey.life_area
    goal = user.strategy_goals.create!(life_area: area, life_journey: journey, horizon: "goal", title: "Goal", position: 0)
    plan = user.strategy_goals.create!(life_area: area, life_journey: journey, parent: goal, horizon: "plan", title: "Plan", position: 0)
    project = user.strategy_goals.create!(life_area: area, life_journey: journey, parent: plan, horizon: "project", title: "Project", position: 0)
    leaf = practice_leaf_for!(project)
    user.strategy_goals.create!(life_area: area, life_journey: journey, parent: leaf, horizon: "day", title: "Battle", scheduled_on: Date.current, position: 0)
    Strategy::CascadeToDaily.call(user: user, life_area: area)

    get dashboard_path
    assert_response :success
    assert_select ".lp-dash-daystrip", count: 1
    assert_select ".lp-dash-anytime", count: 1

    strip_at = response.body.index("lp-dash-daystrip")
    habits_at = response.body.index("lp-dash-anytime")
    assert strip_at, "battle day strip should render"
    assert habits_at, "habits section should render"
    assert_operator strip_at, :<, habits_at,
                    "battle day strip should appear before the habits section in the DOM"
  end

  test "today header shows avatar, day percent, streak, and AP" do
    user = users(:one)
    user.update!(
      name: "Alex Climber",
      character: "fox",
      climb_streak_days: 4,
      climb_streak_on: Date.current,
      total_points: 120
    )
    sign_in_as user
    Onboarding::Run.call(
      user: user,
      area_key: "career",
      title: "Ship",
      ideal_scene: "Live",
      current_reality: "Building",
      next_win: "Launch",
      today_mission: "Write tests",
      closer_percent: 36
    )
    journey = user.reload.primary_focused_journey
    area = journey.life_area
    goal = user.strategy_goals.create!(life_area: area, life_journey: journey, horizon: "goal", title: "Goal", position: 0)
    plan = user.strategy_goals.create!(life_area: area, life_journey: journey, parent: goal, horizon: "plan", title: "Plan", position: 0)
    project = user.strategy_goals.create!(life_area: area, life_journey: journey, parent: plan, horizon: "project", title: "Project", position: 0)
    leaf = practice_leaf_for!(project)
    user.strategy_goals.create!(life_area: area, life_journey: journey, parent: leaf, horizon: "day", title: "Battle", scheduled_on: Date.current, position: 0)
    Strategy::CascadeToDaily.call(user: user, life_area: area)

    get dashboard_path
    assert_response :success

    assert_select ".lp-dash-hero", count: 1
    assert_select ".lp-dash-hero__avatar-img[src*='fox']", count: 1
    assert_select ".lp-dash-hero__name", text: "Alex Climber"
    assert_select ".lp-dash-hero__segs", count: 1
    assert_select ".lp-dash-hero [data-battle-day-target='lpTotal']", text: /120/
    assert_select ".lp-dash-timeline", count: 1
    assert_select ".lp-dash-header", count: 0
  end

  test "today renders while mountain spine is still incomplete" do
    user = users(:one)
    sign_in_as user
    Onboarding::Run.call(
      user: user,
      area_key: "career",
      title: "Ship",
      ideal_scene: "Live",
      current_reality: "Building",
      next_win: "Launch",
      today_mission: "Write tests",
      closer_percent: 20,
      route_mission: true
    )
    user.update!(support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ])

    refute Strategy::HierarchyReady.call(user: user)
    get dashboard_path
    assert_response :success
    assert_match(/Start my climb|Plan Your Route|See your mountain|Battle/i, response.body)
  end
end
