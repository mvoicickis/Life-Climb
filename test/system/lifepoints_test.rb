# frozen_string_literal: true

require "application_system_test_case"

class LifepointsTest < ApplicationSystemTestCase
  test "sign in reaches the climb with greeting" do
    user = users(:one)
    Onboarding::Run.call(
      user: user,
      area_key: "career",
      title: "Ship LifePoints",
      ideal_scene: "App live",
      current_reality: "Building",
      next_win: "Launch",
      today_mission: "Write tests",
      closer_percent: 20,
      route_mission: true
    )
    user.update!(support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ])
    journey = user.reload.primary_focused_journey
    goal = user.strategy_goals.for_kind("goal").roots.first
    plan = goal.children.create!(
      user: user, life_area: journey.life_area, life_journey: journey,
      horizon: "plan", title: "Trail", position: 0
    )
    project = plan.children.create!(
      user: user, life_area: journey.life_area, life_journey: journey,
      horizon: "project", title: "Camp", position: 0
    )
    project_leaf = practice_leaf_for!(project)
    project_leaf.children.create!(
      user: user, life_area: journey.life_area, life_journey: journey,
      horizon: "day", title: "First fight", scheduled_on: Date.current, position: 0
    )

    visit new_session_path
    fill_in "Email", with: user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"

    # Today hides the top brand wordmark — assert real climb chrome instead.
    assert_selector ".lp-dash-nav", wait: 5
    assert_selector ".lp-dash-nav__link", text: /Today/i
    assert_selector ".lp-dash-nav__link", text: /Mountain/i
    assert_text user.display_name
    assert_selector ".lp-dash-header, .lp-dash-timeline", wait: 5
    assert_text(/Anytime|Unscheduled|Win|Action Points|AP/i)
  end
end
