# frozen_string_literal: true

require "test_helper"

class TodayEndDaysControllerTest < ActionDispatch::IntegrationTest
  include ClimbTestHelper

  setup do
    @user = users(:one)
    sign_in_as @user
    seed_climb!(@user, today_mission: "Ship auth")
    dismiss_onboarding_missions!(@user)
    @todo = @user.daily_todos.for_day(Date.current).find_by!(title: "Ship auth")
  end

  test "POST create ends day when all battles are complete" do
    @todo.update!(completed_at: Time.current)

    post today_end_day_path
    assert_redirected_to dashboard_path
    follow_redirect!

    assert_select ".lp-today-v2-recap", count: 1
    assert_select ".lp-today-v2-notch.is-new-day", count: 1
    assert_select ".lp-today-v2-rows", count: 0
  end

  test "POST create blocked when open battles remain" do
    refute @todo.completed?

    post today_end_day_path
    assert_redirected_to dashboard_path
    assert_match(/Clear every battle before you end the day/i, flash[:alert].to_s)

    follow_redirect!
    assert_select ".lp-today-v2-field", count: 1
    assert_select ".lp-today-v2-recap", count: 0
  end

  test "DELETE destroy starts a new day and returns to battlefield" do
    @todo.update!(completed_at: Time.current)
    post today_end_day_path
    follow_redirect!
    assert_select ".lp-today-v2-recap", count: 1

    delete today_end_day_path
    assert_redirected_to dashboard_path
    follow_redirect!

    assert_select ".lp-today-v2-recap", count: 0
    assert_select "#today-end-of-day", count: 1
    assert_select ".lp-today-v2-inline-ack", text: /All battles won today/
    assert_select ".lp-today-v2-rows", count: 0
  end
end
