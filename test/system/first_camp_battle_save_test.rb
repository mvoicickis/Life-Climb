# frozen_string_literal: true

require "application_system_test_case"

class FirstCampBattleSaveTest < ApplicationSystemTestCase
  include ClimbTestHelper

  setup do
    page.driver.browser.manage.window.resize_to(360, 800)

    @user = User.create!(
      name: "First camp save",
      email_address: "first-camp-save-#{SecureRandom.hex(4)}@example.com",
      password: "password12345",
      password_confirmation: "password12345",
      planning_version: 2,
      onboarding_completed_at: Time.current,
      character: "fox"
    )
    @result = Onboarding::Bootstrap.call(
      user: @user,
      goal_title: "Ship the app",
      camp_titles: [ "First camp" ]
    )
    @journey = @result.journey
    @camp = @result.projects.first
    dismiss_onboarding_missions!(@user)
    @user.update_columns(push_offer_last_shown_on: Date.current)
    assert @journey.first_camp_reveal_pending?
  end

  test "save for today creates battle row from first camp setup" do
    battle_title = "Read ten pages"

    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-nav", wait: 8

    visit life_journey_path(@journey)
    assert_selector ".lp-trail.is-first-camp-reveal", wait: 10
    assert_selector ".lp-trail.is-awaiting-tap", wait: 15

    find("#trail-camp-#{@camp.id}", visible: :all).click
    assert_selector ".lp-trail-sheet.is-open", wait: 10
    assert_selector "#trail-sheet-camp-#{@camp.id} .lp-first-camp-setup",
                    visible: :all,
                    wait: 10

    setup_root = "#first-camp-setup-#{@camp.id}"
    assert_selector "#{setup_root} .lp-first-camp-setup__submit[disabled]", visible: :all, wait: 5

    page.execute_script(<<~JS, battle_title, @camp.id)
      const input = document.querySelector(
        `#first-camp-setup-${arguments[1]} [data-first-camp-battle-target='titleField']`
      )
      if (!input) throw new Error("first-camp title field missing")
      input.value = arguments[0]
      input.dispatchEvent(new Event("input", { bubbles: true }))
    JS

    within(setup_root) do
      assert_selector ".lp-first-camp-setup__submit:not([disabled])", wait: 5
      click_button I18n.t("strategy.rpg.trail.first_camp_reveal.submit")
    end

    assert_selector "#trail-battles-list-#{@camp.id}", text: battle_title, wait: 15
    assert_no_selector "#{setup_root}", wait: 10
    refute @journey.reload.first_camp_reveal_pending?
    assert @camp.children.for_kind("day").exists?(title: battle_title)
  end
end
