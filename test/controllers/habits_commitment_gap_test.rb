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
    # Enough timed fights so setup_gap stays quiet once habits hit 3;
    # camps remain short → commitment_gap panel keeps the habits chip.
    3.times do |n|
      @user.daily_todos.create!(
        title: "Timed #{n}", scheduled_on: Date.current, aspect_key: "career",
        start_time: "09:00", end_time: "10:00", position: 10 + n
      )
    end

    post habits_path,
         params: {
           source: "commitment_gap",
           open_reveal: "habit",
           habit: { name: "Water", quantity_checkin: "0" }
         },
         as: :turbo_stream
    assert_response :success
    assert_equal 1, @user.habits.active.on_home.count
    assert_match(%r{data-habits-count[^>]*>1/3}, response.body)
    assert_match(/data-commitment-gap-open-value="habit"/, response.body)
    assert_no_match(/Unfiled Trackers/, response.body)

    post habits_path,
         params: {
           source: "commitment_gap",
           open_reveal: "habit",
           habit: { name: "Walk", quantity_checkin: "0" }
         },
         as: :turbo_stream
    assert_equal 2, @user.habits.active.on_home.count
    assert_match(%r{data-habits-count[^>]*>2/3}, response.body)

    post habits_path,
         params: {
           source: "commitment_gap",
           open_reveal: "habit",
           habit: { name: "Read", quantity_checkin: "0" }
         },
         as: :turbo_stream
    assert_equal 3, @user.habits.active.on_home.count
    assert_match(%r{data-habits-count[^>]*>3/3}, response.body)
    assert_match(/data-next-action-key="commitment_gap"/, response.body)
  end

  test "quantity habit from gap sets unit, nudges unfiled, and refreshes anytime surface" do
    # Spine present so surface renders Anytime (not first-climb plan-route).
    seed_climb!(@user, today_mission: "Ship one thing")
    @user.habits.active.on_home.update_all(show_on_home: false)
    @journey = @user.reload.primary_focused_journey
    @journey.update!(
      commitment_key: "medium",
      commitment_name: "Medium",
      commitment_habit_count: 3,
      commitment_battle_count: 3
    )

    post habits_path,
         params: {
           source: "commitment_gap",
           open_reveal: "habit",
           habit: { name: "Daily steps", quantity_checkin: "1", unit: "steps" }
         },
         as: :turbo_stream
    assert_response :success

    habit = @user.habits.active.on_home.order(:id).last
    assert_equal "Daily steps", habit.name
    assert habit.quantity_checkin?
    assert_equal "steps", habit.unit
    assert_nil habit.area_id
    assert_match(/Unfiled Trackers/, response.body)
    assert_match(/today-battle-surface/, response.body)
    assert_match(/lp-dash-anytime/, response.body)
    assert_match(/Daily steps/, response.body)
  end
end
