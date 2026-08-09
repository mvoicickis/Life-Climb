# frozen_string_literal: true

require "test_helper"

class HabitsCommitmentGapTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(character: "fox")
    sign_in_as @user
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Find a job",
      ideal_scene: "Hired",
      current_reality: "Searching",
      today_mission: "Plan the path",
      closer_percent: 10,
      route_mission: true
    )
    @journey = @user.reload.primary_focused_journey
    @user.habits.active.on_home.update_all(show_on_home: false)
    @journey.update!(
      commitment_key: "medium",
      commitment_name: "Medium",
      commitment_habit_count: 3,
      commitment_battle_count: 3
    )
  end

  test "turbo habit create from commitment_gap updates habits chip and stays open" do
    assert_equal 0, @user.habits.active.on_home.count

    post habits_path,
         params: {
           source: "commitment_gap",
           open_reveal: "habit",
           habit: { name: "Water" }
         },
         as: :turbo_stream
    assert_response :success
    assert_equal 1, @user.habits.active.on_home.count
    assert_match(%r{data-habits-count[^>]*>1/3}, response.body)
    assert_match(/data-commitment-gap-open-value="habit"/, response.body)

    post habits_path,
         params: {
           source: "commitment_gap",
           open_reveal: "habit",
           habit: { name: "Walk" }
         },
         as: :turbo_stream
    assert_equal 2, @user.habits.active.on_home.count
    assert_match(%r{data-habits-count[^>]*>2/3}, response.body)

    post habits_path,
         params: {
           source: "commitment_gap",
           open_reveal: "habit",
           habit: { name: "Read" }
         },
         as: :turbo_stream
    assert_equal 3, @user.habits.active.on_home.count
    assert_match(%r{data-habits-count[^>]*>3/3}, response.body)
  end
end
