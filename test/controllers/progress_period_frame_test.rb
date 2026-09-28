# frozen_string_literal: true

require "test_helper"

class ProgressPeriodFrameTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    Onboarding::Run.call(
      user: @user,
      area_key: "money",
      title: "Financial freedom",
      ideal_scene: "Calm savings",
      current_reality: "Budgeting",
      next_win: "Emergency fund",
      today_mission: "Track spending",
      closer_percent: 25
    )
    @user.reload
  end

  test "full page embeds stats calendar frame" do
    get life_points_path
    assert_response :success

    assert_select "turbo-frame#stats_calendar"
    assert_select ".lp-stats-cal__grid"
    assert_select "#progress_activity", count: 0
    assert_select ".lp-progress-filters", count: 0
  end

  test "calendar turbo frame returns calendar only" do
    month = Date.current.strftime("%Y-%m")

    get life_points_path(stats_month: month), headers: { "Turbo-Frame" => "stats_calendar" }
    assert_response :success

    assert_select "turbo-frame#stats_calendar"
    assert_select ".lp-stats-cal__month"
    assert_select ".lp-stats-hero", count: 0
    assert_match(/data-turbo-frame="stats_calendar"/, response.body)
  end

  test "calendar month cannot navigate past current month" do
    future = (Date.current + 2.months).strftime("%Y-%m")
    get life_points_path(stats_month: future), headers: { "Turbo-Frame" => "stats_calendar" }
    assert_response :success
    assert_select ".lp-stats-cal__month", text: /#{Regexp.escape(Date.current.strftime("%B"))}/i
  end
end
