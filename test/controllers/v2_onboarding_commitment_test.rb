# frozen_string_literal: true

require "test_helper"

class V2OnboardingCommitmentTest < ActionDispatch::IntegrationTest
  setup do
    post registration_url, params: {
      user: {
        name: "Sam",
        email_address: "commit-skip@example.com",
        password: "password12345",
        password_confirmation: "password12345"
      }
    }
    patch v2_onboarding_url(step: "welcome")
    patch v2_onboarding_url(step: "character"), params: { user: { character: "fox" } }
    patch v2_onboarding_url(step: "category"), params: { onboarding: { category: "self" } }
    patch v2_onboarding_url(step: "mountain"), params: { onboarding: { title: "Sleep better" } }
  end

  test "skipping commitment defaults journey to Easy without blocking creation" do
    assert_redirected_to v2_onboarding_path(step: "commitment")

    patch v2_onboarding_url(step: "commitment", skip: true)
    assert_redirected_to v2_onboarding_path(step: "deadline")

    patch v2_onboarding_url(step: "deadline")
    assert_redirected_to v2_onboarding_path(step: "forge")

    user = User.find_by!(email_address: "commit-skip@example.com")
    journey = user.primary_focused_journey
    assert user.onboarding_completed?
    assert_equal "easy", journey.commitment_key
    assert_equal 1, journey.commitment_habit_count
    assert_equal 1, journey.commitment_battle_count
  end

  test "choosing Medium persists on journey after deadline" do
    patch v2_onboarding_url(step: "commitment"), params: { onboarding: { commitment_key: "medium" } }
    patch v2_onboarding_url(step: "deadline")

    journey = User.find_by!(email_address: "commit-skip@example.com").primary_focused_journey
    assert_equal "medium", journey.commitment_key
    assert_equal "Medium", journey.commitment_name
    assert_equal 3, journey.commitment_habit_count
    assert_equal 3, journey.commitment_battle_count
  end
end
