# frozen_string_literal: true

require "test_helper"

class Today::OvershootBonusTest < ActiveSupport::TestCase
  setup { enable_habits! }
  include ClimbTestHelper

  setup do
    @user = users(:one)
    @user.update!(planning_version: 2, total_points: 100)
    seed_climb!(@user, today_mission: "Ship auth")
    @user.habits.active.on_home.destroy_all
    @user.daily_todos.for_day(Date.current).delete_all

    # One growth habit only — easy to drive percent.
    @habit = @user.habits.create!(
      name: "Push-Ups", unit: "reps", points: 5, frequency: "daily",
      active: true, show_on_home: true, stat_type: "growth", goal: 100, quantity_checkin: true
    )
  end

  test "no grant at or below 100 percent" do
    log!(100)
    assert_no_difference -> { @user.reload.total_points } do
      assert_no_difference -> { DayOvershootBonus.count } do
        result = Today::OvershootBonus.sync!(user: @user)
        assert_equal 0, result.granted
      end
    end
  end

  test "first overshoot awards once; identical sync is idempotent" do
    log!(168) # 168% → round(68*0.4)=27
    result = Today::OvershootBonus.sync!(user: @user)
    assert_equal 27, result.granted
    assert_equal 27, result.awarded_ap
    assert_equal 168, result.peak_percent
    assert_equal 127, @user.reload.total_points

    assert_no_difference -> { @user.reload.total_points } do
      assert_no_difference -> { LifePointLedger.where(source_type: "DayOvershootBonus").count } do
        again = Today::OvershootBonus.sync!(user: @user)
        assert_equal 0, again.granted
        assert_equal 27, again.awarded_ap
      end
    end
  end

  test "rise above peak grants delta only" do
    log!(168)
    Today::OvershootBonus.sync!(user: @user)

    log!(180) # target 32, delta 5
    result = Today::OvershootBonus.sync!(user: @user)
    assert_equal 5, result.granted
    assert_equal 32, result.awarded_ap
    assert_equal 180, result.peak_percent
    assert_equal 132, @user.reload.total_points
  end

  test "fall does not claw back; re-rise below peak awards nothing" do
    log!(168)
    Today::OvershootBonus.sync!(user: @user)
    points = @user.reload.total_points

    log!(120)
    result = Today::OvershootBonus.sync!(user: @user)
    assert_equal 0, result.granted
    assert_equal 27, result.awarded_ap
    assert_equal 168, result.peak_percent
    assert_equal points, @user.reload.total_points

    log!(150)
    result = Today::OvershootBonus.sync!(user: @user)
    assert_equal 0, result.granted
    assert_equal points, @user.reload.total_points
  end

  test "daily cap at 50 AP" do
    log!(300) # would be 80 without cap
    result = Today::OvershootBonus.sync!(user: @user)
    assert_equal 50, result.granted
    assert_equal 50, result.awarded_ap
    assert_equal 150, @user.reload.total_points
  end

  private

  def log!(amount)
    entry = @user.daily_logs.find_or_initialize_by(habit: @habit, logged_on: Date.current)
    entry.amount = amount
    entry.goal = 100
    entry.save!
    @habit.reload
  end
end
