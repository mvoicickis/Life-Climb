# frozen_string_literal: true

require "application_system_test_case"

class OverlayHidesNavTest < ApplicationSystemTestCase
  include ClimbTestHelper

  setup do
    page.driver.browser.manage.window.resize_to(360, 640)
    @password = "password12345"
  end

  test "finale continue and share stay in viewport while nav is hidden" do
    user = create_v3_user!("finale-nav")
    result = Onboarding::Bootstrap.call(
      user: user,
      goal_title: "Learn baking",
      camp_titles: [ "Basics" ],
      first_camp_reveal_status: "done"
    )
    journey = result.journey
    journey.mark_onboarding_v3_climb_done!
    camp = result.projects.first
    battle = add_todays_battle!(user: user, project: camp, journey: journey)
    dismiss_onboarding_missions!(user)
    user.update_columns(character: "fox", push_offer_last_shown_on: Date.current, last_finale_on: nil)
    todo = user.daily_todos.for_day(Date.current).find_by!(strategy_goal_id: battle.id)

    sign_in_ui!(user)
    visit dashboard_path
    assert_today_v2_shell!
    assert_selector ".lp-dash-nav", wait: 8

    click_battle_row_check!(todo: todo)
    assert_selector ".lp-today-finale:not([hidden])", wait: 8
    assert_selector ".lp-today-finale__continue", wait: 8
    assert_selector ".lp-today-finale__share", wait: 8

    assert page.evaluate_script("document.body.classList.contains('lp-overlay-open')")
    assert_nav_hidden!
    assert_fully_in_viewport!(".lp-today-finale__continue")
    assert_fully_in_viewport!(".lp-today-finale__share")

    find(".lp-today-finale__continue").click
    assert_no_selector ".lp-today-finale", wait: 8
    refute page.evaluate_script("document.body.classList.contains('lp-overlay-open')")
    assert_selector ".lp-dash-nav", visible: true, wait: 8
  end

  test "base camp intro button stays in viewport while nav is hidden" do
    user = create_v3_user!("base-intro-nav")
    result = Onboarding::Bootstrap.call(
      user: user,
      goal_title: "Learn baking",
      camp_titles: [ "Basics" ],
      first_camp_reveal_status: "done"
    )
    journey = result.journey
    journey.mark_onboarding_v3_climb_done!
    user.update_columns(character: "fox", mountain_trail_tour_ack: 7)
    refute user.base_camp_intro_seen?
    assert user.needs_base_camp_intro?

    sign_in_ui!(user)
    visit life_journey_path(journey)
    assert_selector "#mountain-trail", wait: 8
    assert_selector ".lp-dash-nav", wait: 8
    assert_selector ".lp-trail-base-card__base-row", wait: 8

    find(".lp-trail-base-card__base-row").click
    assert_selector ".lp-base-camp-intro:not([hidden])", wait: 8
    assert_selector ".lp-base-camp-intro .lp-cta", wait: 8

    assert page.evaluate_script("document.body.classList.contains('lp-overlay-open')")
    assert_nav_hidden!
    assert_fully_in_viewport!(".lp-base-camp-intro .lp-cta")

    find(".lp-base-camp-intro .lp-cta").click
    assert_selector ".lp-base-camp-intro[hidden]", visible: :all, wait: 8
    refute page.evaluate_script("document.body.classList.contains('lp-overlay-open')")
    assert_selector ".lp-dash-nav", visible: true, wait: 8
  end

  private

  def create_v3_user!(label)
    User.create!(
      name: "Alex",
      email_address: "#{label}-#{SecureRandom.hex(4)}@example.com",
      password: @password,
      password_confirmation: @password,
      planning_version: 2,
      onboarding_completed_at: Time.current,
      character: "fox"
    )
  end

  def sign_in_ui!(user)
    visit new_session_path
    fill_in "Email", with: user.email_address
    fill_in "Password", with: @password
    click_button "Sign in"
  end

  def assert_nav_hidden!
    hidden = page.evaluate_script <<~JS
      (() => {
        const nav = document.querySelector(".lp-dash-nav");
        if (!nav) return true;
        const style = window.getComputedStyle(nav);
        return style.display === "none" || style.visibility === "hidden";
      })();
    JS
    assert hidden, "expected .lp-dash-nav to be hidden while overlay is open"
  end

  def assert_fully_in_viewport!(selector)
    ok = page.evaluate_script <<~JS
      (() => {
        const el = document.querySelector(#{selector.to_json});
        if (!el) return false;
        const rect = el.getBoundingClientRect();
        const vh = window.innerHeight;
        const vw = window.innerWidth;
        return rect.top >= 0 && rect.left >= 0 && rect.bottom <= vh + 1 && rect.right <= vw + 1
          && rect.width > 0 && rect.height > 0;
      })();
    JS
    assert ok, "expected #{selector} fully inside the 360x640 viewport"
  end
end
