# frozen_string_literal: true

require "test_helper"

class Admin::OnboardingStepFunnelTest < ActiveSupport::TestCase
  test "counts distinct users per step from onboarding events" do
    user = users(:two)
    other = users(:one)

    Analytics::Track.call(user: user, name: "onboarding_step_viewed", properties: { step: "character" })
    Analytics::Track.call(user: user, name: "onboarding_step_completed", properties: { step: "character" })
    Analytics::Track.call(user: user, name: "onboarding_step_viewed", properties: { step: "goal" })
    Analytics::Track.call(user: other, name: "onboarding_step_viewed", properties: { step: "character" })
    Analytics::Track.call(user: other, name: "onboarding_step_completed", properties: { step: "character" })
    Analytics::Track.call(user: other, name: "onboarding_step_completed", properties: { step: "goal" })

    rows = Admin::OnboardingStepFunnel.call[:rows]
    character = rows.find { |row| row.key == "character" }
    goal = rows.find { |row| row.key == "goal" }

    assert_equal 2, character.viewed
    assert_equal 2, character.completed
    assert_equal 1, goal.viewed
    assert_equal 1, goal.completed
    assert_equal 1, goal.drop_off_from_previous
  end
end
