# frozen_string_literal: true

require "test_helper"

class Today::MissSettlementTest < ActiveSupport::TestCase
  include ClimbTestHelper

  setup do
    @user = users(:one)
    seed_climb!(@user, today_mission: "Timed battle")
    @todo = @user.daily_todos.for_day(Date.current).find_by!(title: "Timed battle")
    @todo.update!(
      start_time: "09:00",
      end_time: "10:00",
      lp_reward: 10,
      miss_settled_at: nil
    )
    @user.update!(day_shields_available: 0, day_shield_on: Date.current, total_points: 100)
  end

  test "past end_time debits half lp_reward when shield is spent" do
    now = Time.zone.local(Date.current.year, Date.current.month, Date.current.day, 11, 0, 0)
    assert_difference -> { @user.reload.life_points }, -5 do
      Today::MissSettlement.apply!(user: @user, date: Date.current, now: now)
    end
    assert @todo.reload.miss_settled_at.present?
    assert @todo.missed?
    assert_not @todo.miss_shielded?
  end

  test "available shield blocks the first miss without AP loss" do
    @user.update!(day_shields_available: 1, day_shield_on: Date.current)
    now = Time.zone.local(Date.current.year, Date.current.month, Date.current.day, 11, 0, 0)
    assert_no_difference -> { @user.reload.life_points } do
      Today::MissSettlement.apply!(user: @user, date: Date.current, now: now)
    end
    assert_equal 0, @user.reload.day_shields_available
    assert @todo.reload.miss_settled_at.present?
    assert @todo.miss_shielded?
  end

  test "settlement is idempotent on reload" do
    now = Time.zone.local(Date.current.year, Date.current.month, Date.current.day, 11, 0, 0)
    Today::MissSettlement.apply!(user: @user, date: Date.current, now: now)
    points = @user.reload.life_points
    Today::MissSettlement.apply!(user: @user, date: Date.current, now: now)
    assert_equal points, @user.reload.life_points
  end

  test "completed todos are skipped" do
    @todo.update!(completed_at: Time.current)
    now = Time.zone.local(Date.current.year, Date.current.month, Date.current.day, 11, 0, 0)
    assert_no_difference -> { @user.reload.life_points } do
      Today::MissSettlement.apply!(user: @user, date: Date.current, now: now)
    end
    assert_nil @todo.reload.miss_settled_at
  end
end
