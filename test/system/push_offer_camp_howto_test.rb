# frozen_string_literal: true

require "application_system_test_case"

class PushOfferCampHowtoTest < ApplicationSystemTestCase
  include ClimbTestHelper

  FB_UA = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 " \
          "(KHTML, like Gecko) Mobile/15E148 [FBAN/FBIOS;FBAV/450.0.0.0.0;]"
  ANDROID_CHROME_UA = "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) " \
                      "Chrome/120.0.0.0 Mobile Safari/537.36"

  setup do
    page.driver.browser.manage.window.resize_to(360, 640)

    @user = User.create!(
      name: "Camp howto",
      email_address: "camp-howto-#{SecureRandom.hex(4)}@example.com",
      password: "password12345",
      password_confirmation: "password12345",
      planning_version: 2,
      onboarding_completed_at: Time.current,
      character: "fox",
      push_offer_dismiss_count: 0,
      push_offer_dismissed_at: nil,
      push_offer_permission_denied_at: nil,
      push_offer_last_shown_on: nil,
      push_offer_show_days: 0
    )
    @result = Onboarding::Bootstrap.call(
      user: @user,
      goal_title: "Ship the app",
      camp_titles: [ "First camp", "Second camp" ]
    )
    @journey = @result.journey
    @camp = @result.projects.first
    dismiss_onboarding_missions!(@user)
    @user.push_subscriptions.delete_all
    @journey.clear_first_camp_reveal!
    @battle = @user.strategy_goals.create!(
      life_area: @camp.life_area,
      life_journey: @journey,
      parent: @camp,
      horizon: "day",
      title: "Call mum",
      scheduled_on: Date.current,
      position: 0
    )
    Strategy::CascadeToDaily.call(user: @user, life_area: @camp.life_area)
  end

  def teardown
    reset_emulated_user_agent!
  end

  def reset_emulated_user_agent!
    page.driver.browser.execute_cdp("Emulation.setUserAgentOverride", userAgent: "")
  rescue StandardError
    nil
  end

  def emulate_ua!(ua)
    page.driver.browser.execute_cdp("Emulation.setUserAgentOverride", userAgent: ua)
  end

  def sign_in_open_camp_and_win!(ua:)
    visit new_session_path
    emulate_ua!(ua)
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-nav", wait: 8
    visit life_journey_path(@journey, focus_id: @camp.id)
    assert_selector "#mountain-trail", wait: 8
    open_trail_camp_sheet!(@camp)
    assert_selector "#trail-battle-#{@battle.id} form[action*='battle_win']", visible: :all, wait: 8
    within("#trail-battle-#{@battle.id}") { find(".lp-trail-battles__tick").click }
    assert_selector ".lp-trail-camp-finish__title.is-first-win",
                    text: I18n.t("strategy.rpg.trail.finish_camp_card.first_win_title"),
                    wait: 10
  end

  test "facebook in-app first win shows keep your climb howto without button or home screen copy" do
    sign_in_open_camp_and_win!(ua: FB_UA)

    assert_selector "#mountain-push-offer-host .lp-push-offer.is-camp-howto", wait: 8
    # Label is CSS uppercase — match case-insensitively.
    assert_selector ".lp-push-offer.is-camp-howto", text: /keep your climb/i
    assert_selector ".lp-push-offer.is-camp-howto", text: I18n.t("dash.push_offer.camp_inapp_title")
    assert_selector ".lp-push-offer.is-camp-howto", text: I18n.t("dash.push_offer.camp_inapp_steps")
    assert_no_selector ".lp-push-offer.is-camp-howto", text: /get a reminder tomorrow/i
    assert_no_selector ".lp-push-offer.is-camp-howto", text: I18n.t("dash.push_offer.camp_ios_title")
    assert_no_selector ".lp-push-offer.is-camp-howto", text: I18n.t("dash.push_offer.camp_ios_steps")
    assert_no_selector "#mountain-push-offer-host .lp-push-offer__yes"
    assert_no_selector "#mountain-push-offer-host button"
    assert_selector ".lp-trail-camp-finish__cta", text: I18n.t("strategy.rpg.trail.finish_camp_card.add_another")
    assert_selector ".lp-trail-camp-finish:not(.is-push-offer-open) .lp-trail-camp-finish__cta"
  end

  test "android chrome first win shows mountain remind not howto" do
    sign_in_open_camp_and_win!(ua: ANDROID_CHROME_UA)

    assert_selector "#mountain-push-offer-host .lp-push-offer.is-mountain-reminder", wait: 8
    assert_selector ".lp-push-offer__yes.is-mountain-yes",
                    text: I18n.t("dash.push_offer.mountain_yes"),
                    wait: 5
    assert_no_selector ".lp-push-offer.is-camp-howto"
    assert_no_text(/keep your climb/i)
    assert_no_text(/get a reminder tomorrow/i)
    assert_selector ".lp-trail-camp-finish__cta", text: I18n.t("strategy.rpg.trail.finish_camp_card.add_another")
  end
end
