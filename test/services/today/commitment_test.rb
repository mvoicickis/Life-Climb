# frozen_string_literal: true

require "test_helper"

class Today::CommitmentTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @journey = seed_climb!(@user)
    Today::Commitment.apply_preset!(@journey, "easy")
  end

  test "migration defaults leave existing journeys on Easy 1/1" do
    assert_equal "easy", @journey.commitment_key
    assert_equal "Easy", @journey.commitment_name
    assert_equal 1, @journey.commitment_habit_count
    assert_equal 1, @journey.commitment_battle_count
  end

  test "counts only timed completed battles and requires full N/N" do
    habit = @user.habits.create!(
      name: "Water", unit: "glasses", points: 5, frequency: "daily",
      active: true, show_on_home: true, quantity_checkin: false
    )
    habit.completions.create!(user: @user, completed_on: Date.current, points_awarded: habit.points)

    timed = @user.daily_todos.create!(
      title: "Timed fight", scheduled_on: Date.current, aspect_key: "career",
      completed_at: Time.current, start_time: "09:00", end_time: "10:00", position: 1
    )
    @user.daily_todos.create!(
      title: "Untimed fight", scheduled_on: Date.current, aspect_key: "career",
      completed_at: Time.current, position: 2
    )

    Today::Commitment.apply_preset!(@journey, "medium")
    progress = Today::Commitment.progress(user: @user, journey: @journey)

    assert_equal 1, progress.habit_done
    assert_equal 3, progress.habit_required
    assert_equal 1, progress.battle_done
    assert_equal 3, progress.battle_required
    assert_includes progress.battle_ids, timed.id
    assert_not progress.met?

    Today::Commitment.apply_preset!(@journey, "easy")
    easy = Today::Commitment.progress(user: @user, journey: @journey.reload)
    assert easy.met?
  end

  test "untimed completed battles are ignored" do
    @user.daily_todos.create!(
      title: "Loose card", scheduled_on: Date.current, aspect_key: "career",
      completed_at: Time.current, position: 1
    )
    progress = Today::Commitment.progress(user: @user, journey: @journey)
    assert_equal 0, progress.battle_done
  end

  test "touch_met_streak increments on consecutive met days and suggests level up" do
    habit = @user.habits.create!(
      name: "Water", unit: "glasses", points: 5, frequency: "daily",
      active: true, show_on_home: true, quantity_checkin: false
    )
    3.times do |offset|
      date = Date.current - (2 - offset)
      habit.completions.find_or_create_by!(completed_on: date) do |completion|
        completion.user = @user
        completion.points_awarded = habit.points
      end
      @user.daily_todos.create!(
        title: "Fight #{date}", scheduled_on: date, aspect_key: "career",
        completed_at: Time.zone.parse("#{date} 10:00"),
        start_time: "09:00", end_time: "10:00", position: offset + 1
      )
      Today::Commitment.touch_met_streak!(user: @user, journey: @journey.reload, date: date)
    end

    @journey.reload
    assert_equal 3, @journey.commitment_met_streak_days
    assert Today::Commitment.suggest_level_up?(journey: @journey)

    Today::Commitment.decline_level_up!(@journey)
    assert_not Today::Commitment.suggest_level_up?(journey: @journey.reload)

    @journey.update!(commitment_level_up_declined_on: nil)
    assert Today::Commitment.level_up_preset!(@journey)
    assert_equal "medium", @journey.reload.commitment_key
    assert_equal 3, @journey.commitment_habit_count
  end
end
