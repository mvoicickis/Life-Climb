# frozen_string_literal: true

require "test_helper"

class Patterns::Detectors::WeekdayGapTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @aspect = "self"
  end

  test "ignores weekdays with fewer than three scheduled todos" do
    7.times do |i|
      day = Date.current - i
      create_todo!(scheduled_on: day, completed: true, title: "solo #{i}")
      create_todo!(scheduled_on: day, completed: false, title: "solo-b #{i}")
    end

    assert_nil Patterns::Detectors::WeekdayGap.call(user: @user)
  end

  test "requires at least 30 point gap between best and worst" do
    seed_two_weekdays!(best_wday: 0, worst_wday: 3, best_done: 8, best_total: 10, worst_done: 6, worst_total: 10)

    assert_nil Patterns::Detectors::WeekdayGap.call(user: @user)
  end

  test "fires when gap is at least 30 points and uses scheduled_on weekday" do
    seed_two_weekdays!(best_wday: 0, worst_wday: 3, best_done: 9, best_total: 10, worst_done: 3, worst_total: 10)

    finding = Patterns::Detectors::WeekdayGap.call(user: @user)
    assert_not_nil finding
    assert_equal :weekday_gap, finding.key
    assert_equal 0, finding.data[:best_wday]
    assert_equal 3, finding.data[:worst_wday]
    assert_operator finding.data[:gap], :>=, 30
    assert_match(/Plan /i, finding.action_label)
  end

  test "monday scheduled completed tuesday still counts as monday" do
    monday = most_recent_wday(1)
    wednesday = most_recent_wday(3)

    4.times do |i|
      day = monday - (i * 7)
      todo = create_todo!(scheduled_on: day, completed: false, title: "Mon late #{i}")
      todo.update!(completed_at: (day + 1).beginning_of_day + 1.hour)
      create_todo!(scheduled_on: day, completed: true, title: "Mon ok #{i}")
      create_todo!(scheduled_on: day, completed: true, title: "Mon ok2 #{i}")
    end

    4.times do |i|
      day = wednesday - (i * 7)
      3.times do |j|
        create_todo!(scheduled_on: day, completed: false, title: "Wed miss #{i}-#{j}")
      end
    end

    finding = Patterns::Detectors::WeekdayGap.call(user: @user)
    assert_not_nil finding
    assert_equal 1, finding.data[:best_wday]
    assert_equal 3, finding.data[:worst_wday]
  end

  private

  def create_todo!(scheduled_on:, completed:, title: "Battle")
    @user.daily_todos.create!(
      title: title,
      aspect_key: @aspect,
      scheduled_on: scheduled_on,
      completed_at: completed ? scheduled_on.to_time.change(hour: 12) : nil,
      position: @user.daily_todos.where(scheduled_on: scheduled_on).count
    )
  end

  def most_recent_wday(wday)
    day = Date.current - 1
    day -= 1 while day.wday != wday
    day
  end

  # Only two weekdays — no other days that could steal best/worst.
  def seed_two_weekdays!(best_wday:, worst_wday:, best_done:, best_total:, worst_done:, worst_total:)
    best_anchor = most_recent_wday(best_wday)
    worst_anchor = most_recent_wday(worst_wday)

    place_on_weekday!(anchor: best_anchor, total: best_total, done: best_done, label: "best")
    place_on_weekday!(anchor: worst_anchor, total: worst_total, done: worst_done, label: "worst")
  end

  def place_on_weekday!(anchor:, total:, done:, label:)
    # Spread across enough weeks so days_active stays healthy and under daily cap.
    weeks_needed = [ (total / 3.0).ceil, 4 ].max
    done_left = done
    total.times do |i|
      day = anchor - ((i % weeks_needed) * 7)
      do_complete = done_left.positive?
      done_left -= 1 if do_complete
      create_todo!(scheduled_on: day, completed: do_complete, title: "#{label} #{i}")
    end
  end
end
