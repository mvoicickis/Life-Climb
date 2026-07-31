# frozen_string_literal: true

require "application_system_test_case"

class DestinationSwitcherTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Ship LifePoints",
      ideal_scene: "App live",
      current_reality: "Building",
      next_win: "Launch",
      today_mission: "Write tests",
      closer_percent: 20,
      route_mission: true
    )
    @user.update!(support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ])
    @journey = @user.reload.primary_focused_journey
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    @other = @user.strategy_goals.create!(
      life_area: @journey.life_area, life_journey: @journey,
      horizon: "goal", title: "Health Summit", position: 1
    )
    @goal.children.create!(
      user: @user, life_area: @journey.life_area, life_journey: @journey,
      horizon: "plan", title: "Career Path", position: 0
    ).children.create!(
      user: @user, life_area: @journey.life_area, life_journey: @journey,
      horizon: "project", title: "Resume Camp", position: 0
    ).children.create!(
      user: @user, life_area: @journey.life_area, life_journey: @journey,
      horizon: "day", title: "Write CV", scheduled_on: Date.current, position: 0
    )
    @other.children.create!(
      user: @user, life_area: @journey.life_area, life_journey: @journey,
      horizon: "plan", title: "Run Path", position: 0
    ).children.create!(
      user: @user, life_area: @journey.life_area, life_journey: @journey,
      horizon: "project", title: "5k Camp", position: 0
    ).children.create!(
      user: @user, life_area: @journey.life_area, life_journey: @journey,
      horizon: "day", title: "Jog", scheduled_on: Date.current, position: 0
    )
  end

  test "switching destination updates the hero and plan rail" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"

    within(".lp-dash-nav") { click_link "Mountain" }
    assert_selector "#strategy-world", wait: 5
    assert_selector ".lp-rpg-destination__title", text: /Ship LifePoints/i
    assert_selector ".lp-rpg-path", text: /Career Path/
    assert_no_selector ".lp-rpg-path", text: /Run Path/

    find(".lp-rpg-destination__trigger").click
    assert_selector ".lp-rpg-destination__menu:not([hidden])"
    click_link "Health Summit"

    assert_selector ".lp-rpg-destination__title", text: /Health Summit/i, wait: 5
    assert_selector ".lp-rpg-path", text: /Run Path/
    assert_no_selector ".lp-rpg-path", text: /Career Path/
  end

  test "new destination sheet creates and activates the destination" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"

    within(".lp-dash-nav") { click_link "Mountain" }
    assert_selector ".lp-rpg-destination", wait: 5

    find(".lp-rpg-destination__trigger").click
    click_button "+ New Destination"
    assert_selector "dialog.lp-strategy-sheet.is-goal[open]", wait: 3

    within("dialog#destination-create") do
      fill_in "destination-create-title", with: "Creative Life"
      click_button "Create Destination"
    end

    assert_selector "#first-climb-coach", wait: 5
    assert_selector ".lp-first-climb__goal", text: /Creative Life/
    assert_match(/goal_id=#{@user.strategy_goals.for_kind('goal').find_by!(title: 'Creative Life').id}/, current_url)
  end
end
