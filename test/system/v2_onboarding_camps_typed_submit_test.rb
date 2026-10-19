# frozen_string_literal: true

require "application_system_test_case"

class V2OnboardingCampsTypedSubmitTest < ApplicationSystemTestCase
  include ClimbTestHelper

  setup do
    page.driver.browser.manage.window.resize_to(360, 800)
    @email = "typed-camp-#{SecureRandom.hex(4)}@example.com"
    @password = "password12345"
  end

  test "v2 camps submit flushes typed add field without tapping plus" do
    visit new_registration_path

    fill_in I18n.t("auth.name"), with: "Alex"
    fill_in I18n.t("auth.email"), with: @email
    fill_in I18n.t("auth.password"), with: @password
    fill_in I18n.t("auth.password_confirmation"), with: @password
    click_button I18n.t("auth.register_submit")

    assert_selector "h1", text: I18n.t("v2_onboarding.mountain_name_title"), wait: 8

    fill_in "onboarding_goal", with: "Ship the app"
    click_button I18n.t("v2_onboarding.continue")

    assert_selector "h1", text: I18n.t("v2_onboarding.camps_title"), wait: 8

    fill_in "onboarding_camp_add", with: "Launch beta"
    click_button I18n.t("v2_onboarding.start_climbing")

    assert_selector ".lp-trail", wait: 12

    user = User.find_by!(email_address: @email)
    assert user.onboarding_completed?
    camp = user.strategy_goals.for_kind("project").order(:position).first
    assert_equal "Launch beta", camp.title
  end

  test "summit next goal camps submit flushes typed add field without tapping plus" do
    user = User.create!(
      name: "Summit typed",
      email_address: "summit-typed-#{SecureRandom.hex(4)}@example.com",
      password: @password,
      password_confirmation: @password,
      planning_version: 2,
      onboarding_completed_at: Time.current,
      character: "fox"
    )
    bootstrap = Onboarding::Bootstrap.call(
      user: user,
      goal_title: "First peak",
      camp_titles: [ "Only camp" ]
    )
    finish_camp!(bootstrap.projects.first)

    visit new_session_path
    fill_in I18n.t("auth.email"), with: user.email_address
    fill_in I18n.t("auth.password"), with: @password
    click_button I18n.t("auth.sign_in_submit")
    assert_selector ".lp-dash-nav", wait: 8

    visit summit_next_goal_path
    assert_selector "h1", text: I18n.t("summit_next_goal.mountain_name_title"), wait: 8

    fill_in "summit_onboarding_goal", with: "Second peak"
    click_button I18n.t("v2_onboarding.continue")

    assert_selector "h1", text: I18n.t("v2_onboarding.camps_title"), wait: 8

    fill_in "summit_onboarding_camp_add", with: "New camp step"
    click_button I18n.t("summit_next_goal.start_climbing")

    assert_selector ".lp-trail", wait: 12

    new_journey = user.life_journeys.active.order(:id).last
    assert_equal "Second peak", new_journey.title
    camp = user.strategy_goals.for_kind("project").where(life_journey_id: new_journey.id).order(:position).first
    assert_equal "New camp step", camp.title
    assert_equal "completed", bootstrap.journey.reload.status
  end

  private

  def finish_camp!(camp)
    user = camp.user
    add_todays_battle!(user: user, project: camp, journey: camp.life_journey) if camp.children.for_kind("day").none?
    camp.children.for_kind("day").find_each { |b| b.update!(completed_at: Time.current) }
    camp.complete!
  end
end
