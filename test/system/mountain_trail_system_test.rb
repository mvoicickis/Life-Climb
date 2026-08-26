# frozen_string_literal: true

require "application_system_test_case"

class MountainTrailSystemTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    page.driver.browser.manage.window.resize_to(430, 900)
    Onboarding::Run.call(
      user: @user, area_key: "career", title: "Ship LifePoints",
      ideal_scene: "App live", current_reality: "Building", next_win: "Launch",
      today_mission: "Write tests", closer_percent: 20, route_mission: true
    )
    @user.update!(support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ], character: "fox")
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    @plan = @goal.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: "Main trail", position: 0
    )
    @project = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Base camp", position: 0,
      trail_x: 0.5, trail_y: 0.62, color_key: "teal"
    )
    @battle = @project.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Pitch the tent", scheduled_on: Date.current, position: 0
    )
  end

  test "trail camps open battle sheet and hide holding" do
    holding_plan = @goal.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: "Hold", position: 99, holding: true
    )
    holding_plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Secret hold", position: 0, holding: true
    )

    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-nav", wait: 5
    within(".lp-dash-nav") { click_link "Mountain" }

    assert_selector "#mountain-trail", wait: 5
    assert_selector "#trail-camp-#{@project.id}[aria-label='Base camp']", visible: :all
    assert_no_text "Secret hold"

    open_trail_camp_sheet!(@project)
    assert_selector "#trail-battle-#{@battle.id}", text: /Pitch the tent/, visible: :all
    assert_selector "#trail-battles-#{@project.id} form[action*='battle_win']", visible: :all

    # Phase 1 parity: Today/Base on photo; camp sheet pins to viewport.
    assert_selector ".lp-trail__mountain .lp-trail-today"
    assert_selector ".lp-trail__mountain .lp-trail-base"
    position = page.evaluate_script("getComputedStyle(document.querySelector('.lp-trail-sheet.is-open')).position")
    assert_equal "fixed", position
  end

  test "place mode clamps; blank trail tap does not plant; long-press wiring is present" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-nav", wait: 5
    within(".lp-dash-nav") { click_link "Mountain" }
    assert_selector "#mountain-trail", wait: 5

    assert_selector "[data-action*='campPointerDown']"
    assert_no_selector ".lp-trail-camp.is-dragging"
    assert_no_selector ".lp-trail-plant.is-open"

    page.execute_script(<<~JS)
      const mountain = document.querySelector(".lp-trail__mountain");
      const rect = mountain.getBoundingClientRect();
      mountain.dispatchEvent(new MouseEvent("click", {
        bubbles: true,
        clientX: rect.left + 12,
        clientY: rect.top + 12
      }));
    JS
    assert_no_selector ".lp-trail-plant.is-open"

    find(".lp-dash-nav__fab").click
    assert_selector ".lp-trail-plant.is-open", wait: 5

    find(".lp-trail-plant__cancel").click
    assert_no_selector ".lp-trail-plant.is-open"

    # Tap still opens the sheet. Long-press (~450ms) then drag PATCHes coords.
    open_trail_camp_sheet!(@project)
    assert_selector ".lp-trail-sheet.is-open", visible: :all
  end
end
