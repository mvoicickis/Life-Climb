# frozen_string_literal: true

require "test_helper"

class TodayCheerBarTest < ActionDispatch::IntegrationTest
  include ClimbTestHelper
  include TodayV2TestHelper

  setup do
    @viewer = users(:one)
    @partner = users(:two)
    ClimbPartnership.delete_all
    HighFive.delete_all
    @zone = "Europe/Berlin"
    @partner.create_notification_preference!(time_zone: @zone) unless @partner.notification_preference
    @partner.notification_preference.update!(time_zone: @zone)
    @viewer.create_notification_preference!(time_zone: @zone) unless @viewer.notification_preference
    @viewer.notification_preference.update!(time_zone: @zone)

    travel_to Time.find_zone!(@zone).local(2026, 11, 19, 9, 30, 0) do
      seed_climb!(@viewer, today_mission: "Viewer fight")
      seed_climb!(@partner, area_key: "self", today_mission: "Partner fight")
      invite = ClimbTogether::Invite.call(user: @viewer)
      ClimbTogether::Accept.call(user: @partner, token: invite.token)
      @battle = @viewer.strategy_goals.find_by!(horizon: "day", title: "Viewer fight")
      dismiss_onboarding_missions!(@viewer)
    end
    sign_in_as @viewer
  end

  test "greeting follows local morning afternoon evening" do
    @viewer.update!(name: "Mareks")

    travel_to Time.find_zone!(@zone).local(2026, 11, 19, 8, 0, 0) do
      get dashboard_path
      assert_response :success
      assert_select "#today-top-bar .lp-today-top__hi", text: "Good morning, Mareks"
      assert_select "#today-top-bar .lp-today-top__date", text: "Thursday, 19 Nov"
    end

    travel_to Time.find_zone!(@zone).local(2026, 11, 19, 14, 0, 0) do
      get dashboard_path
      assert_response :success
      assert_select "#today-top-bar .lp-today-top__hi", text: "Good afternoon, Mareks"
    end

    travel_to Time.find_zone!(@zone).local(2026, 11, 19, 20, 0, 0) do
      get dashboard_path
      assert_response :success
      assert_select "#today-top-bar .lp-today-top__hi", text: "Good evening, Mareks"
    end
  end

  test "unseen cheer morphs top bar then mark seen hides it next load" do
    travel_to Time.find_zone!(@zone).local(2026, 11, 19, 10, 0, 0) do
      cheer = HighFive.create!(
        from_user: @partner,
        to_user: @viewer,
        strategy_goal: @battle,
        daily_todo: @viewer.daily_todos.for_day(Date.current).find_by(strategy_goal_id: @battle.id)
      )
      @partner.update!(name: "Birdie")

      get dashboard_path
      assert_response :success
      assert_select "#today-top-bar[data-today-top-bar-auto-cheer-value='true']", count: 1
      assert_select "#today-top-bar[data-today-top-bar-cheer-id-value=?]", cheer.id.to_s
      assert_select "#today-top-bar .lp-today-top__cheer .lp-today-top__hi",
                    text: "Birdie cheered you"
      assert_select "#today-top-bar .lp-today-top__cheer-badge .lp-icon svg", count: 1
      assert_select "#today-top-bar .lp-today-top__cheer .lp-today-top__date",
                    text: "just now"

      post today_cheer_seen_path(id: cheer.id)
      assert_response :no_content
      assert cheer.reload.seen_at.present?

      get dashboard_path
      assert_response :success
      assert_select "#today-top-bar[data-today-top-bar-auto-cheer-value]", count: 0
      assert_select "#today-top-bar .lp-today-top__cheer .lp-today-top__hi", count: 0
    end
  end

  test "cheer seen for another user cheer is ignored" do
    travel_to Time.find_zone!(@zone).local(2026, 11, 19, 10, 0, 0) do
      foreign = HighFive.create!(
        from_user: @viewer,
        to_user: @partner,
        strategy_goal: @partner.strategy_goals.find_by!(horizon: "day", title: "Partner fight")
      )

      post today_cheer_seen_path(id: foreign.id)
      assert_response :no_content
      assert_nil foreign.reload.seen_at
    end
  end
end
