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

    assert_text "LifePoints"
    assert_text(/Today|Mountain|Start my climb|#{Regexp.escape(user.display_name)}/i)
  end
end
