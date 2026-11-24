# frozen_string_literal: true

require "test_helper"

class FirstTipsMountainTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      name: "Alex",
      email_address: "first-tip-mtn-#{SecureRandom.hex(4)}@example.com",
      password: "password12345",
      password_confirmation: "password12345",
      onboarding_completed_at: Time.current
    )
    @result = Onboarding::Bootstrap.call(
      user: @user,
      goal_title: "Ship",
      camp_titles: [ "Launch" ],
      complete_onboarding: true,
      first_camp_reveal_status: "pending"
    )
    @journey = @result.journey
    mark_onboarding_v3!(@journey)
    @user.mark_first_tip_seen!("mountain")
    sign_in_as(@user)
  end

  test "does not render camp tip during first camp reveal" do
    get life_journey_path(@journey)

    assert_response :success
    assert @journey.reload.first_camp_reveal_pending?
    assert_select "[data-controller='first-tip']", count: 0
  end

  private

  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: "password12345" }
  end

  def mark_onboarding_v3!(journey)
    flags = (journey.setup_flags.presence || {}).stringify_keys.merge(
      Onboarding::Bootstrap::ONBOARDING_V3_FLAG => "true"
    )
    journey.update_columns(setup_flags: flags, updated_at: Time.current)
  end
end
