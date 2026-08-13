# frozen_string_literal: true

require "test_helper"

class Battles::UncompleteTodoTest < ActiveSupport::TestCase
  include ClimbTestHelper

  setup do
    @user = users(:one)
    seed_climb!(@user, today_mission: "Undo safe")
    @todo = @user.daily_todos.for_day(Date.current).find_by!(title: "Undo safe")
    @session = {}
    @user.update!(total_points: 100)
  end

  test "uncomplete does not change total_points" do
    Battles::CompleteTodo.call(todo: @todo, user: @user, session: @session)
    points = @user.reload.life_points
    assert @todo.reload.completed?

    assert_no_difference -> { @user.reload.life_points } do
      assert Battles::UncompleteTodo.call(todo: @todo, user: @user)
    end

    assert_equal points, @user.reload.life_points
    assert_nil @todo.reload.completed_at
  end
end
