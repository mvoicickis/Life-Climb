# frozen_string_literal: true

require "test_helper"

class Admin::OnboardingStepFunnelTest < ActiveSupport::TestCase
  test "counts distinct users per step from onboarding events" do
    user = users(:two)
    other = users(:one)

    Analytics::Track.call(user: user, name: "onboarding_step_viewed", properties: { step: "goal" })
    Analytics::Track.call(user: user, name: "onboarding_step_completed", properties: { step: "goal" })
    Analytics::Track.call(user: user, name: "onboarding_step_viewed", properties: { step: "camps" })
    Analytics::Track.call(user: other, name: "onboarding_step_viewed", properties: { step: "goal" })
    Analytics::Track.call(user: other, name: "onboarding_step_completed", properties: { step: "goal" })
    Analytics::Track.call(user: other, name: "onboarding_step_completed", properties: { step: "camps" })

    rows = Admin::OnboardingStepFunnel.call[:rows]
    goal = rows.find { |row| row.key == "goal" }
    camps = rows.find { |row| row.key == "camps" }

    assert_equal 2, goal.viewed
    assert_equal 2, goal.completed
    assert_equal 1, camps.viewed
    assert_equal 1, camps.completed
    assert_equal 1, camps.drop_off_from_previous
  end

  test "counts distinct users per step from mountain tour events" do
    user = users(:two)
    other = users(:one)

    Analytics::Track.call(user: user, name: "mountain_tour_step_viewed", properties: { step: "today" })
    Analytics::Track.call(user: user, name: "mountain_tour_step_completed", properties: { step: "today" })
    Analytics::Track.call(user: other, name: "mountain_tour_step_viewed", properties: { step: "today" })
    Analytics::Track.call(user: other, name: "mountain_tour_step_completed", properties: { step: "today" })

    rows = Admin::OnboardingStepFunnel.call(Admin::OnboardingStepFunnel::MOUNTAIN_TOUR)[:rows]
    today = rows.find { |row| row.key == "today" }

    assert_equal 2, today.viewed
    assert_equal 2, today.completed
    assert_equal 0, today.drop_off_from_previous
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
