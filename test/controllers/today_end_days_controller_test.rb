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

    assert_not Today::BattlefieldDay.ended?(session)

    post today_end_day_path
    assert_redirected_to dashboard_path
    follow_redirect!

    assert Today::BattlefieldDay.ended?(session)
    assert_select ".lp-today-v2-recap", count: 1
    assert_select ".lp-today-v2-notch.is-new-day", count: 1
  end

  test "POST create blocked when open battles remain" do
    assert @todo.open?

    post today_end_day_path
    assert_redirected_to dashboard_path
    assert_match(/open battle/i, flash[:alert].to_s)
    assert_not Today::BattlefieldDay.ended?(session)

    follow_redirect!
    assert_select ".lp-today-v2-field", count: 1
    assert_select ".lp-today-v2-recap", count: 0
  end

  test "DELETE destroy starts a new day and returns to battlefield" do
    @todo.update!(completed_at: Time.current)
    post today_end_day_path
    assert Today::BattlefieldDay.ended?(session)

    delete today_end_day_path
    assert_redirected_to dashboard_path
    follow_redirect!

    assert_not Today::BattlefieldDay.ended?(session)
    assert_select ".lp-today-v2-recap", count: 0
    assert_select ".lp-today-v2-field", count: 1
  end
end
