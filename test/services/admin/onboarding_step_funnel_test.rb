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

  test "counts distinct users per step from mountain tour events" do
    user = users(:two)
    other = users(:one)

    Analytics::Track.call(user: user, name: "mountain_tour_step_viewed", properties: { step: "goal" })
    Analytics::Track.call(user: user, name: "mountain_tour_step_completed", properties: { step: "goal" })
    Analytics::Track.call(user: user, name: "mountain_tour_step_viewed", properties: { step: "camp" })
    Analytics::Track.call(user: other, name: "mountain_tour_step_viewed", properties: { step: "goal" })
    Analytics::Track.call(user: other, name: "mountain_tour_step_completed", properties: { step: "goal" })
    Analytics::Track.call(user: other, name: "mountain_tour_step_completed", properties: { step: "camp" })

    rows = Admin::OnboardingStepFunnel.call(Admin::OnboardingStepFunnel::MOUNTAIN_TOUR)[:rows]
    goal = rows.find { |row| row.key == "goal" }
    camp = rows.find { |row| row.key == "camp" }

    assert_equal 2, goal.viewed
    assert_equal 2, goal.completed
    assert_equal 1, camp.viewed
    assert_equal 1, camp.completed
    assert_equal 1, camp.drop_off_from_previous
  end

  test "counts anonymous landing funnel events" do
    3.times { Analytics::Track.call(name: "landing_viewed") }
    Analytics::Track.call(name: "signup_started")

    rows = Admin::OnboardingStepFunnel.call(Admin::OnboardingStepFunnel::LANDING)[:rows]
    landing = rows.find { |row| row.key == "landing_viewed" }
    signup = rows.find { |row| row.key == "signup_started" }

    assert_equal 3, landing.viewed
    assert_equal 3, landing.completed
    assert_equal 1, signup.viewed
    assert_equal 1, signup.completed
    assert_equal 2, signup.drop_off_from_previous
  end
end
