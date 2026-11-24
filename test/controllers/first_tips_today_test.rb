# frozen_string_literal: true

require "test_helper"

class FirstTipsTodayTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      name: "Alex",
      email_address: "first-tip-today-#{SecureRandom.hex(4)}@example.com",
      password: "password12345",
      password_confirmation: "password12345",
      onboarding_completed_at: Time.current
    )
    @result = Onboarding::Bootstrap.call(
      user: @user,
      goal_title: "Ship",
      camp_titles: [ "Launch" ],
      complete_onboarding: true,
      first_camp_reveal_status: "done"
    )
    @journey = @result.journey
    Onboarding::PlantBattles.call(
      user: @user,
      journey: @journey,
      battle_titles: [ "Battle one" ]
    )
    @journey.set_first_camp_win_nudge!
    sign_in_as(@user)
  end

  test "renders circle tip for eligible v3 today visit" do
    get dashboard_path

    assert_response :success
    assert_select ".lp-today-v2-row__tap-hint", count: 0
    assert_select "[data-controller='first-tip']", count: 1
    assert_select "[data-first-tip-key-value=?]", "circle"
    assert_select "[data-first-tip-ack-url-value=?]", first_tip_ack_path
  end

  test "tip preview query is ignored in test" do
    get dashboard_path, params: { tip: "mountain" }

    assert_response :success
    assert_select "[data-controller='first-tip']", count: 1
    assert_select "[data-first-tip-key-value=?]", "circle"
  end

  private

  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: "password12345" }
  end
end
