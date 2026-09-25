# frozen_string_literal: true

require "test_helper"

class LifeJourneyFirstCampWinNudgeTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      name: "Alex",
      email_address: "nudge-flag-#{SecureRandom.hex(4)}@example.com",
      password: "password12345",
      password_confirmation: "password12345"
    )
    @result = Onboarding::Bootstrap.call(
      user: @user,
      goal_title: "Ship it",
      camp_titles: [ "First camp" ]
    )
    @journey = @result.journey
  end

  test "set and clear win nudge flag" do
    refute @journey.first_camp_win_nudge_pending?

    @journey.set_first_camp_win_nudge!
    assert @journey.reload.first_camp_win_nudge_pending?

    @journey.clear_first_camp_win_nudge!
    refute @journey.reload.first_camp_win_nudge_pending?
  end
end
