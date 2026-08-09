# frozen_string_literal: true

require "test_helper"

class Today::TimelineTest < ActiveSupport::TestCase
  include ClimbTestHelper

  setup do
    @user = users(:one)
    seed_climb!(@user, today_mission: "Morning focus")
    @area = @user.primary_focused_journey.life_area
    @leaf = @user.strategy_goals.for_kind("day").first.parent
    @morning = @user.daily_todos.for_day(Date.current).find_by!(title: "Morning focus")
    @morning.update!(start_time: "09:00", end_time: "10:00")
  end

  test "gap of 60 minutes or more inserts a free segment" do
    afternoon = create_todo!("Afternoon deep work", "11:00", "12:00")
    result = Today::Timeline.build(user: @user, todos: [ @morning, afternoon ])
    types = result.segments.map(&:type)
    assert_equal %i[item free item], types
    assert_equal 60, result.segments[1].minutes
  end

  test "gap under 60 minutes has no free segment" do
    soon = create_todo!("Quick follow-up", "10:30", "11:00")
    result = Today::Timeline.build(user: @user, todos: [ @morning, soon ])
    assert_equal %i[item item], result.segments.map(&:type)
  end

  test "now ratio sits inside the active item segment" do
    now = Time.zone.local(Date.current.year, Date.current.month, Date.current.day, 9, 30, 0)
    result = Today::Timeline.build(user: @user, todos: [ @morning ], now: now)
    assert_equal 0, result.now_segment_index
    assert_in_delta 0.5, result.now_ratio, 0.01
  end

  test "now ratio sits inside a free gap" do
    afternoon = create_todo!("Afternoon deep work", "12:00", "13:00")
    now = Time.zone.local(Date.current.year, Date.current.month, Date.current.day, 11, 0, 0)
    result = Today::Timeline.build(user: @user, todos: [ @morning, afternoon ], now: now)
    free = result.segments.find { |segment| segment.type == :free }
    assert_equal free.index, result.now_segment_index
    assert_in_delta 0.5, result.now_ratio, 0.01
  end

  test "unscheduled todos stay out of gap math" do
    loose = create_todo!("Loose end", nil, nil)
    result = Today::Timeline.build(user: @user, todos: [ @morning, loose ])
    assert_equal %i[item], result.segments.map(&:type)
    assert_includes result.unscheduled.map(&:id), loose.id
  end

  private

  def create_todo!(title, start_time, end_time)
    day = @leaf.children.create!(
      user: @user,
      life_area: @area,
      life_journey: @user.primary_focused_journey,
      horizon: "day",
      title: title,
      scheduled_on: Date.current,
      position: @leaf.children.maximum(:position).to_i + 1
    )
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)
    todo = @user.daily_todos.for_day(Date.current).find_by!(strategy_goal_id: day.id)
    todo.update!(start_time: start_time, end_time: end_time) if start_time && end_time
    todo
  end
end
