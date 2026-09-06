# frozen_string_literal: true

require "application_system_test_case"

class OnboardingMountainTourAnchoringTest < ApplicationSystemTestCase
  # Tour needs a warm Mountain render; parallel browser runs can
  # finish sign-in before the session cookie is ready without extra waits.
  parallelize(workers: 1)

  setup do
    @user = User.create!(
      name: "Tour",
      email_address: "tour-anchor-#{SecureRandom.hex(4)}@example.com",
      password: "password12345",
      password_confirmation: "password12345"
    )
  end

  test "tour shows centered Today CTA immediately" do
    bootstrap_and_visit!

    assert_selector "[data-controller='onboarding-mountain-tour']", wait: 5
    assert_selector "a.lp-onboarding-tour__cta", text: I18n.t("v2_onboarding.mountain_tour.today_cta"), wait: 5
    assert_no_selector "button.lp-onboarding-tour__next"
    assert_text I18n.t("v2_onboarding.mountain_tour.today")
  end

  test "mountain plant fab uses camp wording not project" do
    bootstrap_and_visit!

    label = I18n.t("strategy.rpg.trail.plant_project")
    assert_selector ".lp-dash-nav__fab[aria-label='#{label}']", visible: :all, wait: 5
    assert_no_selector ".lp-dash-nav__fab[aria-label='Plant a project']", visible: :all
  end

  private

  def bootstrap_and_visit!
    Onboarding::Bootstrap.call(
      user: @user,
      goal_title: "Become a Ruby Developer",
      camp_titles: [ "Get certified" ]
    )
    journey = @user.reload.primary_focused_journey
    assert journey.present?, "expected bootstrap to create a focused journey"

    @user.update!(character: "fox") unless @user.character_chosen?

    sign_in_and_visit_mountain!(journey)
    journey
  end

  def sign_in_and_visit_mountain!(journey)
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_no_current_path new_session_path, wait: 10

    visit life_journey_path(journey)
    assert_mountain_onboarding_tour_ready!
  end

  def assert_mountain_onboarding_tour_ready!
    assert_selector "#mountain-trail.lp-trail.is-v4", wait: 10
    assert_selector "[data-controller='onboarding-mountain-tour']", wait: 10
    assert_selector ".lp-dash-nav__fab", visible: :all, wait: 5
  end
end
