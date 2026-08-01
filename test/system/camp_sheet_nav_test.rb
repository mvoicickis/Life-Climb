# frozen_string_literal: true

require "application_system_test_case"

class CampSheetNavTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    page.driver.browser.manage.window.resize_to(390, 844)

    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Ship the MVP",
      ideal_scene: "App live",
      current_reality: "Building",
      next_win: "Launch",
      today_mission: "Design battle card",
      closer_percent: 40,
      route_mission: true
    )
    @user.update!(support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ])
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    @plan = @goal.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: "MVP path", position: 0
    )
    @camp_a = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Get first 100 users", position: 0
    )
    @camp_b = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Ship landing page", position: 1
    )
    @camp_a.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Ask 5 friends for feedback",
      scheduled_on: Date.current, position: 0
    )
    @camp_b.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Draft hero headline",
      scheduled_on: Date.current, position: 0
    )
  end

  test "trail window and sheet switchers change focused camp practices" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-nav", wait: 5

    visit life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @camp_a.id)
    assert_selector ".lp-rpg-node.is-planning-focus", text: /Get first 100 users/i, wait: 5
    assert_selector ".lp-rpg-practice-focus.is-entered", text: /Ask 5 friends for feedback/i
    assert_no_selector ".lp-rpg-practice-focus.is-entered", text: /Draft hero headline/i

    find(".lp-rpg-trail__shift.is-next", wait: 3).click
    assert_current_path life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @camp_b.id), wait: 5
    assert_selector ".lp-rpg-node.is-planning-focus", text: /Ship landing page/i, wait: 5
    assert_selector ".lp-rpg-practice-focus.is-entered", text: /Draft hero headline/i
    assert_no_selector ".lp-rpg-practice-focus.is-entered", text: /Ask 5 friends for feedback/i

    find(".lp-rpg-practice-focus.is-entered .lp-rpg-practice-focus__nav.is-prev", wait: 3).click
    assert_current_path life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @camp_a.id), wait: 5
    assert_selector ".lp-rpg-practice-focus.is-entered", text: /Ask 5 friends for feedback/i, wait: 5
    assert_no_selector ".lp-rpg-practice-focus.is-entered", text: /Draft hero headline/i

    FileUtils.mkdir_p("/opt/cursor/artifacts/screenshots")
    page.save_screenshot("/opt/cursor/artifacts/screenshots/camp-sheet-nav.png")
  end

  test "empty camp shows clear empty state after switch" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-nav", wait: 5

    empty = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Empty camp", position: 2
    )

    visit life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: empty.id)
    assert_selector ".lp-rpg-practice-focus.is-entered", text: /Empty camp/i, wait: 5
    assert_selector ".lp-rpg-todays-practice__empty", text: /No practices yet/i
  end
end
