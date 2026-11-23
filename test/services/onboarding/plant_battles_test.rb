# frozen_string_literal: true

require "test_helper"

class OnboardingPlantBattlesTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      name: "Alex",
      email_address: "plant-battles-#{SecureRandom.hex(4)}@example.com",
      password: "password12345",
      password_confirmation: "password12345"
    )
    @result = Onboarding::Bootstrap.call(
      user: @user,
      goal_title: "Ship",
      camp_titles: [ "Launch" ],
      complete_onboarding: false
    )
    @journey = @result.journey
    @journey.mark_onboarding_v3_climb_done!
  end

  test "creates day battles on first camp and syncs today" do
    battles = Onboarding::PlantBattles.call(
      user: @user,
      journey: @journey,
      battle_titles: [ "Draft post", "Share update" ]
    )

    assert_equal 2, battles.size
    assert @user.daily_todos.where(scheduled_on: Date.current).exists?
    assert @journey.reload.first_camp_win_nudge_pending?
  end

  test "second call with different titles does not duplicate battles" do
    Onboarding::PlantBattles.call(
      user: @user,
      journey: @journey,
      battle_titles: [ "Draft post" ]
    )

    assert_no_difference -> { @user.strategy_goals.for_kind("day").count } do
      Onboarding::PlantBattles.call(
        user: @user,
        journey: @journey,
        battle_titles: [ "Another title" ]
      )
    end
  end
end
