# frozen_string_literal: true

require "test_helper"

class SettingsCommitmentEligibilityTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(character: "fox")
    sign_in_as @user
    @journey = seed_climb!(@user)
    Today::Commitment.apply_preset!(@journey, "easy")
  end

  test "settings shows ineligible Medium/Hard as disabled with gap copy" do
    get settings_path
    assert_response :success
    assert_select ".lp-settings-commitment__btn.is-disabled", minimum: 2
    assert_match(/needs 3 Today habits/i, response.body)
    assert_match(/needs 3 planned camps/i, response.body)
    assert_select "a[href=?]", habits_path, text: /Open Habits/i
    assert_select "a[href=?]", life_journey_path(@journey), text: /Open Mountain/i
  end

  test "direct PATCH with ineligible Medium is rejected server-side" do
    assert_equal "easy", @journey.commitment_key

    patch commitment_settings_path, params: { commitment_key: "medium" }
    assert_redirected_to settings_path(highlight: "commitment")
    follow_redirect!
    assert_match(/needs 3 Today habits/i, response.body)
    assert_match(/needs 3 planned camps/i, response.body)
    assert_equal "easy", @journey.reload.commitment_key
  end

  test "eligible Medium applies from Settings" do
    3.times do |n|
      @user.habits.create!(
        name: "H#{n}", unit: "times", points: 5, frequency: "daily",
        active: true, show_on_home: true, quantity_checkin: false
      )
    end
    goal = @user.strategy_goals.for_area(@journey.life_area_id).for_kind("goal").roots.first
    plan = goal.children.for_kind("plan").ordered.first
    2.times do |n|
      plan.children.create!(
        user: @user, life_area: @journey.life_area, life_journey: @journey,
        horizon: "project", title: "Extra bare #{n}", position: 20 + n
      )
    end
    assert_operator Today::Commitment.camp_capacity(@journey), :>=, 3

    patch commitment_settings_path, params: { commitment_key: "medium" }
    assert_redirected_to settings_path(highlight: "commitment")
    assert_equal "medium", @journey.reload.commitment_key
  end
end
