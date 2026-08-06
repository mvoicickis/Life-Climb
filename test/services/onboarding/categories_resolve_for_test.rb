# frozen_string_literal: true

require "test_helper"

class OnboardingCategoriesResolveForTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "uses explicit valid category" do
    assert_equal "money", Onboarding::Categories.resolve_for(user: @user, explicit: "money")
  end

  test "falls back to journey then other" do
    seed_climb!(@user, area_key: "career")
    assert_equal "career", Onboarding::Categories.resolve_for(user: @user, explicit: "nope")

    user = users(:two)
    assert_equal "other", Onboarding::Categories.resolve_for(user: user, explicit: nil)
  end
end
