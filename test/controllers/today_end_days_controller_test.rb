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

  test "POST create closes day in end-of-day card without separate recap screen" do
    @todo.update!(completed_at: Time.current)

    post today_end_day_path
    assert_redirected_to dashboard_path
    follow_redirect!

    assert_select "#today-end-of-day.is-closed", count: 1
    assert_select ".lp-today-v2-signoff__title", text: "See you tomorrow"
    assert_select ".lp-today-v2-eod-stats", text: /You won 1 of 1 battles/
    assert_select ".lp-today-v2-eod-share__btn", text: "Share your day"
    assert_select ".lp-today-v2-inline-ack", text: /All battles won today/
    assert_select ".lp-today-v2-bridge", count: 0
    assert_select "a", text: "Reopen day"
    assert_select ".lp-today-v2-notch.is-day-closed", count: 1
    assert_select ".lp-today-v2-rows", count: 0
  end

  test "POST create blocked when open battles remain" do
    refute @todo.completed?

    post today_end_day_path
    assert_redirected_to dashboard_path
    assert_match(/Clear every battle before you end the day/i, flash[:alert].to_s)

    follow_redirect!
    assert_select ".lp-today-v2-field", count: 1
    assert_select "#today-end-of-day.is-closed", count: 0
  end

  test "DELETE destroy reopens day via link on closed card" do
    @todo.update!(completed_at: Time.current)
    post today_end_day_path
    follow_redirect!
    assert_select "#today-end-of-day.is-closed", count: 1

    delete today_end_day_path
    assert_redirected_to dashboard_path
    follow_redirect!

    assert_select "#today-end-of-day.is-closed", count: 0
    assert_select "#today-end-of-day", count: 1
    assert_select ".lp-today-v2-big-ack__title", text: /Crushed it|Survived|Rough day/
    assert_select ".lp-today-v2-inline-ack", text: /All battles won today/
    assert_select ".lp-today-v2-rows", count: 0
    assert_select ".lp-today-v2-notch.is-end-day", count: 1
  end
end
