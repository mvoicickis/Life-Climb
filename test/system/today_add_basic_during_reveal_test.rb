# frozen_string_literal: true

require "application_system_test_case"

class TodayAddBasicDuringRevealTest < ApplicationSystemTestCase
  include ClimbTestHelper

  setup do
    enable_habits!
    page.driver.browser.manage.window.resize_to(360, 740)

    @user = User.create!(
      name: "Add basic reveal",
      email_address: "add-basic-reveal-#{SecureRandom.hex(4)}@example.com",
      password: "password12345",
      password_confirmation: "password12345",
      planning_version: 2,
      onboarding_completed_at: Time.current,
      character: "fox"
    )
    @result = Onboarding::Bootstrap.call(
      user: @user,
      goal_title: "Bal climb",
      camp_titles: [ "Bal" ]
    )
    @journey = @result.journey
    @camp = @result.projects.first
    dismiss_onboarding_missions!(@user)
    @user.update_columns(push_offer_last_shown_on: Date.current)

    area = @journey.life_area
    @user.strategy_goals.where(life_area_id: area.id, horizon: "day", scheduled_on: Date.current).destroy_all
    @user.daily_todos.for_day(Date.current).destroy_all
    @user.habits.destroy_all

    assert @journey.first_camp_reveal_pending?
  end

  test "add basic from today opens base camp sheet and reveal returns after close" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_today_v2_shell!

    visit dashboard_path
    add_label = I18n.t("dash.anytime.add_basic")
    assert_selector "a.lp-dash-anytime__add-basic", text: add_label, wait: 8

    find("a.lp-dash-anytime__add-basic", text: add_label).click

    assert_selector "#mountain-trail .lp-trail-sheet.is-open", wait: 10
    assert_selector "#trail-base-sheet input[data-trail-battles-target='titleField']", wait: 8
    assert_selector ".lp-dash-nav", visible: true, wait: 5
    assert @journey.reload.first_camp_reveal_pending?

    page.go_back

    assert_no_selector "#mountain-trail .lp-trail-sheet.is-open", wait: 8
    assert_selector ".lp-trail.is-first-camp-reveal", wait: 5
    assert_selector ".lp-first-camp-reveal__skip.is-visible", wait: 10
    assert @journey.reload.first_camp_reveal_pending?
    assert_not page.evaluate_script("document.body.classList.contains('is-trail-camp-sheet-keyboard-open')")
  end
end
