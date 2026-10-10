# frozen_string_literal: true

require "test_helper"

class OnboardingCampsUiTest < ActionDispatch::IntegrationTest
  test "camps step empty state shows green add and disabled submit" do
    post registration_url, params: {
      user: {
        name: "Trail",
        email_address: "trail-#{SecureRandom.hex(4)}@example.com",
        password: "password12345",
        password_confirmation: "password12345"
      }
    }
    follow_redirect!

    patch v2_onboarding_url(step: "goal"), params: { onboarding: { goal: "Become a web developer" } }
    follow_redirect!

    get v2_onboarding_path(step: "camps")

    assert_response :success
    assert_select "a.lp-feedback-fab", count: 0
    assert_select "button.lp-ob-steps__add-btn.lp-ob-steps__add-btn--primary"
    assert_select "input[type=submit][disabled].lp-cta"
    assert_select "input[type=submit].lp-cta.lp-cta--ready", count: 0
    assert_match(/Break it into small steps/i, response.body)
    assert_select "#onboarding_camp_add[placeholder=?]", I18n.t("v2_onboarding.camps_add_placeholder_first")
  end
end
