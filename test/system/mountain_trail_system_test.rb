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
    @user.update!(support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ], character: "fox", mountain_trail_tour_ack: 7)
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

    # Next-action bar is in the trail scroll, after the photo.
    assert_selector ".lp-trail__scroll .lp-trail__dock .lp-trail-base-card"
    assert_no_selector ".lp-trail__mountain .lp-trail-today"
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
    assert_no_selector "#mountain-trail.is-relocating"
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

    # Tap still opens the sheet. Long-press unlocks relocate; the path stays lit until the tent moves.
    open_trail_camp_sheet!(@project)
    assert_selector ".lp-trail-sheet.is-open", visible: :all
  end

  test "long-press unlocks relocate and keeps the path lit after lift" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-nav", wait: 5
    within(".lp-dash-nav") { click_link "Mountain" }
    assert_selector "#mountain-trail", wait: 5
    assert_selector "#trail-camp-#{@project.id}", visible: :all
    assert_no_selector "#mountain-trail.is-relocating"

    page.execute_script(<<~JS)
      const camp = document.querySelector("#trail-camp-#{@project.id}");
      const rect = camp.getBoundingClientRect();
      const x = rect.left + rect.width / 2;
      const y = rect.top + rect.height / 2;
      const opts = {
        bubbles: true, cancelable: true, pointerId: 1, pointerType: "touch",
        clientX: x, clientY: y, button: 0
      };
      camp.dispatchEvent(new PointerEvent("pointerdown", opts));
      window.__lpRelocateCamp = camp;
      window.__lpRelocateOpts = opts;
    JS
    sleep 0.55
    page.execute_script(<<~JS)
      window.__lpRelocateCamp.dispatchEvent(new PointerEvent("pointerup", window.__lpRelocateOpts));
    JS

    assert_selector "#mountain-trail.is-relocating", wait: 3
    assert_selector "#trail-camp-#{@project.id}.is-relocating"
    assert_selector ".lp-trail-glow", visible: :all
    assert_selector ".lp-trail-placing", text: /Tap the path/, visible: :all

    page.execute_script("document.querySelector('.lp-trail-placing button')?.click()")
    assert_no_selector "#mountain-trail.is-relocating"
  end

  test "camp sheet can move an open battle up" do
    later = @project.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Pack the bags", scheduled_on: Date.current, position: 1
    )

    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-nav", wait: 5
    within(".lp-dash-nav") { click_link "Mountain" }
    assert_selector "#mountain-trail", wait: 5
    assert_selector ".lp-trail-camp__ring", visible: :all
    assert_selector ".lp-trail-camp__status", text: /battles? ready/i, visible: :all

    open_trail_camp_sheet!(@project)
    within("#trail-battle-#{later.id}", visible: :all) { find(".lp-trail-battles__kebab-btn", visible: :all).click }
    click_button "Move up"
    assert_selector "#trail-battles-#{@project.id} .lp-trail-battles__list li:first-child", text: /Pack the bags/, visible: :all, wait: 5
  end

  test "base camp can add a daily that asks how many pages" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-nav", wait: 5
    within(".lp-dash-nav") { click_link "Mountain" }
    assert_selector ".lp-trail-base-card", wait: 5

    find(".lp-trail-base-card").click
    assert_selector "#trail-base-sheet:not([hidden])", visible: :all, wait: 5

    within("#trail-base-sheet") do
      fill_in placeholder: "Add something you do every day", with: "Read"
      find("label.is-qty").click
      click_button "Add battle"
    end

    assert_selector "#trail-base-sheet", text: /Read/, visible: :all, wait: 5
    find("#trail-base-sheet .lp-trail-battles__tick").click
    assert_selector ".lp-trail-log.is-open", wait: 5
    assert_selector ".lp-trail-log__prompt", text: /pages/i
    assert_selector ".lp-trail-log__amount[readonly]"
  end

  test "base camp kebab closes when tapping outside" do
    @battle.update!(repeat: "daily")

    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-nav", wait: 5
    within(".lp-dash-nav") { click_link "Mountain" }
    assert_selector ".lp-trail-base-card", wait: 5

    find(".lp-trail-base-card").click
    assert_selector "#trail-base-sheet:not([hidden])", visible: :all, wait: 5
    find("#trail-base-sheet .lp-trail-battles__kebab-btn").click
    assert_selector "#trail-base-sheet .lp-trail-battles__kebab[open]", wait: 3

    find(".lp-trail-sheet__title", visible: :all).click
    assert_no_selector "#trail-base-sheet .lp-trail-battles__kebab[open]", wait: 3
  end
end
