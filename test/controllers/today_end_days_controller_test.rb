# frozen_string_literal: true

require "test_helper"

class TodayEndDaysControllerTest < ActionDispatch::IntegrationTest
  include ClimbTestHelper

  setup do
    @user = users(:one)
    sign_in_as @user
    seed_climb!(@user, today_mission: "Ship auth")
    dismiss_onboarding_missions!(@user)
    @user.habits.destroy_all
    @todo = @user.daily_todos.for_day(Date.current).find_by!(title: "Ship auth")
  end

  test "POST create closes day into step 3 without separate recap screen" do
    @todo.update!(completed_at: Time.current)
    post today_eod_acknowledge_path
    follow_redirect!

    post today_end_day_path
    assert_redirected_to dashboard_path
    follow_redirect!

    assert_select ".lp-today-v2-eod-takeover.is-closed", count: 1
    assert_select ".lp-today-v2-eod-closed__title", text: "See you tomorrow"
    assert_select ".lp-today-v2-eod-closed__share", text: "Share your day"
    assert_select ".lp-today-v2-inline-ack", text: /All battles won today/
    assert_select ".lp-today-v2-eod-plan", count: 0
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
    assert_select ".lp-today-v2-eod-closed", count: 0
  end

  test "DELETE destroy reopens day to step 2 plan" do
    @todo.update!(completed_at: Time.current)
    post today_eod_acknowledge_path
    follow_redirect!
    post today_end_day_path
    follow_redirect!
    assert_select ".lp-today-v2-eod-closed", count: 1

    delete today_end_day_path
    assert_redirected_to dashboard_path
    follow_redirect!

    assert_select ".lp-today-v2-eod-closed", count: 0
    assert_select ".lp-today-v2-eod-plan__title", text: "What are you certain you can do tomorrow?"
    assert_select ".lp-today-v2-eod-win", count: 0
    assert_select ".lp-today-v2-inline-ack", text: /All battles won today/
    assert_select ".lp-today-v2-rows", count: 0
    assert_select ".lp-today-v2-notch.is-end-day", count: 1
  end
end
