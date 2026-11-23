# frozen_string_literal: true

require "application_system_test_case"

class V2OnboardingViewportCtaTest < ApplicationSystemTestCase
  setup do
    @email = "viewport-ob-#{SecureRandom.hex(4)}@example.com"
    @password = "password12345"
  end

  %w[climb battles celebrate].each do |step|
    test "#{step} primary cta fits 360x640 viewport" do
      user = fast_track_to_step!(step)
      sign_in_via_ui!(user)
      visit v2_onboarding_path(step: step)
      assert_primary_cta_in_viewport!
      refute_nil user
    end
  end

  private

  def sign_in_via_ui!(user)
    session = user.sessions.create!
    jar = ActionDispatch::TestRequest.create.cookie_jar
    jar.signed[:session_id] = session.id

    visit root_path
    page.driver.browser.manage.add_cookie(
      name: "session_id",
      value: jar[:session_id],
      path: "/"
    )
  end

  def fast_track_to_step!(step)
    email = "viewport-#{step}-#{SecureRandom.hex(4)}@example.com"
    user = User.create!(
      name: "Alex",
      email_address: email,
      password: @password,
      password_confirmation: @password,
      character: "fox"
    )
    Onboarding::Bootstrap.call(
      user: user,
      goal_title: "Learn Latvian",
      camp_titles: %w[Basics Conversation Fluency],
      complete_onboarding: false,
      first_camp_reveal_status: "done"
    )
    journey = user.primary_focused_journey
    case step
    when "climb"
      user
    when "battles"
      journey.mark_onboarding_v3_climb_done!
      user
    when "celebrate"
      journey.mark_onboarding_v3_climb_done!
      Onboarding::PlantBattles.call(
        user: user,
        journey: journey,
        battle_titles: [ "Practice ten words" ]
      )
      user
    else
      raise ArgumentError, "unknown step #{step}"
    end
  end

  def assert_primary_cta_in_viewport!
    page.driver.browser.manage.window.resize_to(360, 640)
    assert_selector ".lp-ob__cta-dock .lp-cta", wait: 8
    assert_selector ".lp-ob-climb__next.is-shown", wait: 15 if page.has_css?(".lp-ob-climb__next", wait: 0)
    visible = page.evaluate_script <<~JS
      (() => {
        const button = document.querySelector(".lp-ob__cta-dock .lp-cta:not([disabled])")
          || document.querySelector(".lp-ob__cta-dock .lp-cta.is-shown")
          || document.querySelector(".lp-ob__cta-dock .lp-cta");
        if (!button) return false;
        const rect = button.getBoundingClientRect();
        const vh = window.innerHeight;
        return rect.top >= 0 && rect.bottom <= vh + 1;
      })();
    JS
    assert visible, "expected onboarding CTA fully inside the viewport at 360x640"
  end
end
