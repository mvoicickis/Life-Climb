# frozen_string_literal: true

require "test_helper"

class LifeJourneysCompletedRedirectTest < ActionDispatch::IntegrationTest
  setup do
    Goals::Current.clear_cache!
    @user = User.create!(
      name: "Redirect",
      email_address: "mountain-redirect-#{SecureRandom.hex(4)}@example.com",
      password: "password12345",
      password_confirmation: "password12345",
      planning_version: 2,
      onboarding_completed_at: Time.current
    )
    sign_in_as @user
    bootstrap = Onboarding::Bootstrap.call(
      user: @user,
      goal_title: "Old climb",
      camp_titles: [ "Camp" ]
    )
    @old = bootstrap.journey
    finish_camp!(bootstrap.projects.first)
    Journeys::StartNextGoal.call(
      user: @user,
      old_journey: @old,
      goal_title: "New climb",
      camp_titles: [ "Fresh camp" ]
    )
    @new = Goals::Current.journey_for(user: @user.reload)
  end

  test "completed journey mountain redirects to current journey" do
    get life_journey_path(@old)
    assert_redirected_to life_journey_path(@new)
  end

  private

  def finish_camp!(camp)
    camp.children.for_kind("day").find_each { |b| b.update!(completed_at: Time.current) }
    camp.complete!
  end
end
