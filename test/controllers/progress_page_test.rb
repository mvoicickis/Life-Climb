# frozen_string_literal: true

require "test_helper"

class ProgressPageTest < ActionDispatch::IntegrationTest
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
  end

  test "progress page renders premium analytics sections" do
    get life_points_path
    assert_response :success
    assert_match(/Progress/i, response.body)
    assert_match(/LifePoints growth|Am I becoming/i, response.body)
    assert_match(/7 Days/i, response.body)
    assert_match(/Weekly activity/i, response.body)
    assert_match(/Achievements/i, response.body)
    assert_match(/lp-dash-nav/i, response.body)
    assert_match(/progress-charts/i, response.body)
  end

  test "period query updates selected chip" do
    get life_points_path(period: "30d")
    assert_response :success
    assert_match(/period=30d.*is-active|is-active.*30 Days/i, response.body)
  end
end
