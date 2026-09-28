# frozen_string_literal: true

require "test_helper"

class ProgressMorePageTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    allow_extra_climbs!(@user)
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

  test "more stats page renders charts and weekday section" do
    get more_life_points_path
    assert_response :success

    assert_select ".lp-stats-more__head", text: /More stats/i
    assert_select ".lp-stats-more__back[href=?]", life_points_path
    assert_select ".lp-stats-more__picker-btn.is-active", text: /Weekly/i
    assert_select ".lp-stats-more__card", minimum: 2
    assert_select ".lp-stats-more__chart", minimum: 2
    assert_select "#stats-more-weekdays-heading", text: /Wins by weekday/i
    assert_select ".lp-dash-nav__link.is-active", text: /Stats/i
    assert_select ".lp-feedback-fab", count: 0
  end

  test "daily period switch renders daily picker active" do
    get more_life_points_path(period: "daily")
    assert_response :success
    assert_select ".lp-stats-more__picker-btn.is-active", text: /Daily/i
  end

  test "stats home links to more stats" do
    get life_points_path
    assert_response :success
    assert_select "a.lp-stats-more-link[href=?]", more_life_points_path
  end
end
