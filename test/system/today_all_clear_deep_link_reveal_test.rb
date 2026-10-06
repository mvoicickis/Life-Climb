# frozen_string_literal: true

require "application_system_test_case"

class TodayAllClearDeepLinkRevealTest < ApplicationSystemTestCase
  include ClimbTestHelper

  setup do
    page.driver.browser.manage.window.resize_to(360, 740)

    @user = User.create!(
      name: "Deep link reveal",
      email_address: "deep-link-reveal-#{SecureRandom.hex(4)}@example.com",
      password: "password12345",
      password_confirmation: "password12345",
      planning_version: 2,
      onboarding_completed_at: Time.current
    )
    @result = Onboarding::Bootstrap.call(
      user: @user,
      goal_title: "Bal climb",
      camp_titles: [ "Bal" ]
    )
    @journey = @result.journey
    @camp = @result.projects.first
    @battle = @camp.children.for_kind("day").first
    Strategy::CascadeToDaily.call(user: @user, life_area: @journey.life_area)
    dismiss_onboarding_missions!(@user)
    @user.update!(push_offer_last_shown_on: Date.current)
    @todo = @user.daily_todos.for_day(Date.current).find_by!(strategy_goal_id: @battle.id)
    assert @journey.first_camp_reveal_pending?
  end

  test "add another battle opens camp sheet and composer while reveal pending" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_today_v2_shell!

    visit dashboard_path

    assert_selector "#companion-pick-prompt", wait: 8
    find("#companion-pick-prompt .lp-companion-pick__option input[value='fox']", visible: :all).click
    assert_no_selector "#companion-pick-prompt", wait: 8

    assert_selector "#today-battlefield-rows .lp-today-v2-row", wait: 8

    click_battle_row_check!(todo: @todo)
    assert_selector "#today-battlefield-end-day-host .lp-today-empty-cta__pill",
                      text: I18n.t("dash.battlefield.add_another_battle"),
                      wait: 8

    click_on I18n.t("dash.battlefield.add_another_battle")

    assert_selector "#mountain-trail .lp-trail-sheet.is-open", wait: 8
    assert_selector "#trail-battles-#{@camp.id} [data-trail-battles-target='composerForm']:not([hidden])",
                    visible: :all,
                    wait: 8
    assert_no_selector ".lp-trail.is-first-camp-reveal", wait: 5
  end
end
