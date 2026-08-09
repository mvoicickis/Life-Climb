# frozen_string_literal: true

require "application_system_test_case"

class OnboardingCommitmentLockNudgeTest < ApplicationSystemTestCase
  test "disabled Medium card nudges without selecting or submitting" do
    email = "commit-nudge-#{SecureRandom.hex(4)}@example.com"

    visit new_registration_path
    fill_in "Your name", with: "Sam"
    fill_in "Email", with: email
    fill_in "Password", with: "password12345"
    fill_in "Confirm password", with: "password12345"
    click_button "Create account"

    click_button "See My First Step"

    choose "Fox", allow_label_click: true
    click_button "Continue"

    find(".lp-adventure__category", match: :first).click
    assert_selector "#onboarding_title", wait: 5

    fill_in "onboarding_title", with: "Sleep better"
    click_button "Continue"

    assert_selector ".lp-adventure__commitment-card.is-disabled", minimum: 1, wait: 5
    assert_selector "[data-controller='commitment-lock']"

    medium = find(".lp-adventure__commitment-card.is-disabled", match: :first)
    medium.click

    assert medium[:class].include?("is-nudge"), "expected is-nudge feedback class after tap"
    # Radios are visually hidden (opacity: 0); assert checked state in the DOM.
    assert page.has_css?("input[name='onboarding[commitment_key]'][value='easy']:checked", visible: :all)
    assert page.has_no_css?("input[name='onboarding[commitment_key]'][value='medium']:checked", visible: :all)
    assert page.has_css?("input[name='onboarding[commitment_key]'][value='medium'][disabled]", visible: :all)
    assert_selector ".lp-adventure__commitment-card.is-selected", text: /Easy/i
    assert_current_path v2_onboarding_path(step: "commitment")
  end
end
