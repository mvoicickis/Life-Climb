# frozen_string_literal: true

require "test_helper"

class OnboardingBootstrapTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      name: "Alex",
      email_address: "bootstrap-#{SecureRandom.hex(4)}@example.com",
      password: "password12345",
      password_confirmation: "password12345"
    )
  end

  test "creates goal plan project battles and marks onboarding complete" do
    result = Onboarding::Bootstrap.call(
      user: @user,
      goal_title: "Become a Ruby Developer",
      camp_title: "Get certified",
      battle_titles: [ "Study chapter 1", "Write one test" ]
    )

    @user.reload
    journey = result.journey

    assert @user.onboarding_completed?
    assert_equal "purpose", journey.life_area.key
    assert_equal "other", journey.setup_flag("onboarding_category")
    assert_equal "true", journey.setup_flag(Onboarding::Bootstrap::BOOTSTRAP_FLAG)
    assert_equal "easy", journey.commitment_key
    assert_nil journey.setup_flag("route")

    assert_equal "Become a Ruby Developer", result.goal.title
    assert_equal "Get certified", result.plan.title
    assert result.project.title.present?
    assert_equal 2, result.battles.size
    assert_equal Date.current, result.battles.first.scheduled_on

    assert Strategy::HierarchyReady.call(user: @user, journey: journey)
    assert @user.daily_todos.where(scheduled_on: Date.current).exists?
    assert @user.needs_onboarding_mountain_tour?(journey)
  end

  test "rejects empty battles" do
    error = assert_raises(Onboarding::Bootstrap::Error) do
      Onboarding::Bootstrap.call(
        user: @user,
        goal_title: "Ship it",
        camp_title: "Build",
        battle_titles: []
      )
    end

    assert_equal I18n.t("v2_onboarding.need_battle"), error.message
    refute @user.reload.onboarding_completed?
    assert_equal 0, @user.life_journeys.count
  end
end
