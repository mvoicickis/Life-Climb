# frozen_string_literal: true

require "test_helper"

class TodayDoneBattlesFoldTest < ActionDispatch::IntegrationTest
  include ClimbTestHelper

  setup do
    @user = users(:one)
    sign_in_as @user
    seed_climb!(@user, today_mission: "Ship auth")
    @todo = @user.daily_todos.for_day(Date.current).find_by!(title: "Ship auth")
    @todo.update!(start_time: "09:00", end_time: "10:00")
  end

  test "completed battles leave the timeline rail and land in a collapsed fold when open work remains" do
    other = @user.daily_todos.create!(
      title: "Still open",
      scheduled_on: Date.current,
      aspect_key: "career",
      start_time: "14:00",
      end_time: "15:00",
      position: 50
    )
    @todo.update!(completed_at: Time.current)

    get dashboard_path
    assert_response :success

    assert_select ".lp-dash-timeline__item .lp-dash-tcard[data-todo-id=?]", @todo.id, count: 0
    assert_select ".lp-dash-timeline__item .lp-dash-tcard[data-todo-id=?]", other.id, count: 1
    assert_select ".lp-dash-done-fold:not([open])", count: 1
    assert_select ".lp-dash-done-fold__summary .lp-dash-done-fold__label", text: "Done today"
    assert_select ".lp-dash-done-fold__count", text: "1"
    assert_select ".lp-dash-done-fold .lp-dash-tcard.is-done[data-todo-id=?]", @todo.id
    assert_select ".lp-dash-done-fold .lp-dash-tcard[data-todo-id=?] form[action=?]",
                  @todo.id, complete_daily_todo_path(@todo)
  end

  test "fold defaults open when every battle is done" do
    @todo.update!(completed_at: Time.current)

    get dashboard_path
    assert_response :success

    assert_select ".lp-dash-timeline__rail", count: 0
    assert_select ".lp-dash-done-fold[open]", count: 1
    assert_select ".lp-dash-done-fold .lp-dash-tcard.is-done[data-todo-id=?]", @todo.id
  end

  test "completed timed battle does not keep a rail segment for the now line" do
    @todo.update!(completed_at: Time.current)
    open = @user.daily_todos.create!(
      title: "Later fight",
      scheduled_on: Date.current,
      aspect_key: "career",
      start_time: "16:00",
      end_time: "17:00",
      position: 60
    )

    get dashboard_path
    assert_response :success

    assert_select ".lp-dash-timeline__item[data-starts-at]", count: 1
    assert_select ".lp-dash-timeline__item .lp-dash-tcard[data-todo-id=?]", open.id
    assert_select ".lp-dash-timeline__item .lp-dash-tcard[data-todo-id=?]", @todo.id, count: 0
  end
end
