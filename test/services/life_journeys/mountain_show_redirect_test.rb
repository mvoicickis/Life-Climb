# frozen_string_literal: true

require "test_helper"

class LifeJourneysMountainShowRedirectTest < ActiveSupport::TestCase
  setup do
    Goals::Current.clear_cache!
    @user = User.create!(
      name: "Redirect svc",
      email_address: "redirect-svc-#{SecureRandom.hex(4)}@example.com",
      password: "password12345",
      password_confirmation: "password12345",
      planning_version: 2,
      onboarding_completed_at: Time.current
    )
  end

  test "returns path to current journey when viewing completed non-current mountain" do
    bootstrap_a = Onboarding::Bootstrap.call(
      user: @user,
      goal_title: "Old",
      camp_titles: [ "A" ]
    )
    old = bootstrap_a.journey
    finish_camp!(bootstrap_a.projects.first)

    Journeys::StartNextGoal.call(
      user: @user,
      old_journey: old,
      goal_title: "New",
      camp_titles: [ "B" ]
    )

    new_journey = Goals::Current.journey_for(user: @user.reload)
    path = LifeJourneys::MountainShowRedirect.path_for(user: @user, journey: old.reload)
    assert_equal "/life_journeys/#{new_journey.id}", path
  end

  test "returns nil for active journey" do
    bootstrap = Onboarding::Bootstrap.call(
      user: @user,
      goal_title: "Active",
      camp_titles: [ "A" ]
    )
    path = LifeJourneys::MountainShowRedirect.path_for(user: @user, journey: bootstrap.journey)
    assert_nil path
  end

  private

  def finish_camp!(camp)
    camp.children.for_kind("day").find_each { |b| b.update!(completed_at: Time.current) }
    camp.complete!
  end
end
