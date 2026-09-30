# frozen_string_literal: true

require "test_helper"

class TodayEmptyBasicRowTest < ActionDispatch::IntegrationTest
  include ClimbTestHelper

  setup do
    @user = users(:one)
    sign_in_as @user
    seed_climb!(@user, today_mission: "Ship auth")
    dismiss_onboarding_missions!(@user)
    enable_habits!
    @journey = @user.reload.primary_focused_journey
  end

  test "photo today with no basics shows one grey add basic link" do
    @user.habits.destroy_all

    get dashboard_path
    assert_response :success
    assert_select ".lp-dash.is-today-photo", count: 1
    assert_select "a.lp-dash-anytime__add-basic",
                  text: I18n.t("dash.anytime.add_basic"),
                  count: 1
    assert_select "a.lp-dash-anytime__add-basic[href*='open_base=1']", count: 1
    assert_select ".lp-dash-anytime__empty", count: 0
  end

  test "photo today with basics does not show add basic row" do
    @user.habits.destroy_all
    @user.habits.create!(
      name: "Water",
      unit: "times",
      points: 5,
      frequency: "daily",
      active: true,
      show_on_home: true,
      stat_type: "growth"
    )

    get dashboard_path
    assert_response :success
    assert_select "a.lp-dash-anytime__add-basic", count: 0
    assert_select ".lp-dash-tcard.is-habit", minimum: 1
  end
end
