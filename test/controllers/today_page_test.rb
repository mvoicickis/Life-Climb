# frozen_string_literal: true

require "test_helper"

class TodayPageTest < ActionDispatch::IntegrationTest
  test "today renders for hierarchy-ready user with closing ring" do
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
    assert_select ".lp-dash-battle"
    assert_select ".lp-dash-battle__ring"
  end

  test "today climb band shows avatar, percent, battle, and streak" do
    user = users(:one)
    user.update!(
      name: "Alex Climber",
      character: "fox",
      climb_streak_days: 4,
      climb_streak_on: Date.current
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

    # Seed a known mountain percent via completed project progress when available;
    # otherwise assert the band wires whatever @closer the controller computes.
    get dashboard_path
    assert_response :success

    assert_select ".lp-dash-climb", count: 1
    assert_select ".lp-dash-climb__avatar-img[src*='character-fox']", count: 1
    assert_select ".lp-dash-climb__name", text: "Alex Climber"
    assert_select ".lp-dash-climb__climber[style*='--lp-trail']", count: 1
    assert_select ".lp-dash-climb__climber-img[src*='character-fox']", count: 1
    assert_select ".lp-dash-bar__fill[data-battle-day-target='goalBar']", count: 1
    assert_select ".lp-dash-climb__pct[data-battle-day-target='goalPct']", count: 1
    assert_select ".lp-dash-climb__label[data-battle-day-target='momentum']", count: 1
    assert_select ".lp-dash-climb__climber[data-battle-day-target='campArt']", count: 1
    assert_select ".lp-dash-climb__path", count: 1
    assert_select ".lp-dash-climb__path-lit", count: 1
    assert_select ".lp-dash-climb__path[stroke-dasharray]", count: 1

    climber_style = css_select(".lp-dash-climb__climber").first["style"].to_s
    assert_match(/--lp-trail:\s*(\d+)/, climber_style)
    trail_pct = climber_style[/\d+/].to_i
    closer = css_select(".lp-dash-climb__pct").first.text.to_i
    assert_equal [ closer, 6 ].max, trail_pct, "climber should be inset at least 6% on the trail"
    assert_select ".lp-dash-bar__fill[style=?]", "width: #{closer}%"
    assert_select ".lp-dash-climb__path-lit[stroke-dasharray=?]", "#{closer} 100"
    assert_select ".lp-dash-climb__pct", text: closer.to_s
    assert_select ".lp-dash-climb__label", text: /#{closer}%\s*up the mountain/i

    # Battle card still sits below the climb band, unchanged.
    assert_select ".lp-dash-battle", count: 1
    assert_select ".lp-dash-battle__title", text: /Today.?s battle/i
    assert_select ".lp-dash-battle__sub", text: /Win today.?s battle/i
    assert_select ".lp-dash-hero", count: 0

    assert_select ".lp-climb-streak.is-compact", count: 1
    assert_match(/4-day|4 dienas/i, response.body)
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
