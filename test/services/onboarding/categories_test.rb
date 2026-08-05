# frozen_string_literal: true

require "test_helper"

class OnboardingCategoriesTest < ActiveSupport::TestCase
  test "growth and other share purpose area key with distinct ids" do
    growth = Onboarding::Categories.find("growth")
    other = Onboarding::Categories.find("other")

    assert_equal "purpose", growth.area_key
    assert_equal "purpose", other.area_key
    assert_equal "sprout", growth.icon
    assert_equal "dots", other.icon
    refute_equal growth.id, other.id
  end

  test "id_for_journey prefers onboarding_category flag over area key" do
    user = users(:one)
    journey = Onboarding::Run.call(
      user: user,
      area_key: "purpose",
      title: "Grow",
      route_mission: true,
      onboarding_category: "other"
    )

    assert_equal "other", Onboarding::Categories.id_for_journey(journey)
  end
end
