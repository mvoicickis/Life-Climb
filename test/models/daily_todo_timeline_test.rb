# frozen_string_literal: true

require "test_helper"

class DailyTodoTimelineTest < ActiveSupport::TestCase
  include ClimbTestHelper

  setup do
    @user = users(:one)
    seed_climb!(@user, today_mission: "Ship auth")
    @todo = @user.daily_todos.for_day(Date.current).find_by!(title: "Ship auth")
  end

  test "times default to null and both-or-neither validation" do
    assert_nil @todo.start_time
    assert_nil @todo.end_time
    assert_not @todo.timed?

    @todo.start_time = "09:00"
    assert_not @todo.valid?
    assert_includes @todo.errors[:base].join, "both"

    @todo.end_time = "08:00"
    assert_not @todo.valid?

    @todo.end_time = "10:00"
    assert @todo.valid?
    assert @todo.timed?
  end
end
