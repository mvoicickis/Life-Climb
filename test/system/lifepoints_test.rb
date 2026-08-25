# frozen_string_literal: true

require "application_system_test_case"

class LifepointsTest < ApplicationSystemTestCase
  include ClimbTestHelper

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
    Strategy::CascadeToDaily.call(user: user, life_area: journey.life_area)
    dismiss_onboarding_missions!(user)

    visit new_session_path
    fill_in "Email", with: user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"

    assert_selector ".lp-dash-nav.is-today-v2", wait: 5
    assert_selector ".lp-dash-nav__link", text: /Today/i
    assert_selector ".lp-dash-nav__link", text: /Mountain/i
    assert_text user.display_name
    assert_today_v2_shell!
    assert_battle_row!(title: "First fight", camp: "Camp")
    assert_no_legacy_today_shell!
  end
end
