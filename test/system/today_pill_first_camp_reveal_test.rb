# frozen_string_literal: true

require "application_system_test_case"

class TodayPillFirstCampRevealTest < ApplicationSystemTestCase
  include ClimbTestHelper

  setup do
    page.driver.browser.manage.window.resize_to(360, 740)

    @user = User.create!(
      name: "Today pill reveal",
      email_address: "today-pill-reveal-#{SecureRandom.hex(4)}@example.com",
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

    assert @journey.first_camp_reveal_pending?
  end

  test "add todays battle pill opens first camp setup while reveal is pending" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_today_v2_shell!

    visit dashboard_path
    pill_label = I18n.t("dash.battlefield.empty_cta.add_todays_battle")
    assert_selector "#today-battlefield-body a.lp-today-empty-cta__pill",
                    text: pill_label,
                    wait: 8

    pill = find("#today-battlefield-body a.lp-today-empty-cta__pill", text: pill_label)
    pill.scroll_to(:center)
    pill.click

    assert_selector "#mountain-trail .lp-trail-sheet.is-open", wait: 10
    assert_selector ".lp-trail.is-first-camp-reveal", wait: 5

    setup_root = "#first-camp-setup-#{@camp.id}"
    assert_selector "#{setup_root} .lp-first-camp-setup", visible: :all, wait: 10
    assert_selector "#{setup_root} input[type=submit][value=?]",
                    I18n.t("strategy.rpg.trail.first_camp_reveal.submit"),
                    visible: :all,
                    wait: 5
  end
end
