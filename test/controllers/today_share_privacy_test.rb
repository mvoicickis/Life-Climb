# frozen_string_literal: true

require "test_helper"

class TodaySharePrivacyTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.daily_todos.delete_all
    sign_in_as @user
    @zone = "Europe/Berlin"
    @user.create_notification_preference!(time_zone: @zone) unless @user.notification_preference
    @user.notification_preference.update!(time_zone: @zone)
    @secret_goal = "SECRET GOAL XYZ"
    @secret_battle = "SECRET BATTLE XYZ"
    @today = Date.new(2026, 8, 6)
  end

  test "today notch recap share attribute never includes goal or battle titles" do
    travel_to Time.find_zone!(@zone).local(2026, 8, 6, 12, 0, 0) do
      seed_climb!(@user, today_mission: @secret_battle)
      goal = @user.strategy_goals.find_by!(horizon: "goal")
      goal.update!(title: @secret_goal)
      project = @user.strategy_goals.find_by!(horizon: "project", title: "Auth")
      journey = @user.primary_focused_journey
      battle = project.children.find_by!(horizon: "day", title: @secret_battle)
      battle.update!(
        completed_at: Time.find_zone!(@zone).local(2026, 8, 6, 9, 0, 0)
      )

      get dashboard_path
      assert_response :success

      root = css_select("#today-dash-root").first
      assert root, "expected today dash root"
      recap = root["data-today-notch-recap-text-value"].to_s
      assert recap.present?
      refute_includes recap, @secret_goal
      refute_includes recap, @secret_battle
      assert_includes recap, "lifeclimb.app"
    end
  end

  test "finale share data attribute never includes goal title" do
    skip unless @user.has_attribute?(:last_finale_on)

    travel_to Time.find_zone!(@zone).local(2026, 8, 6, 12, 0, 0) do
      @user.update!(last_finale_on: nil)
      seed_climb!(@user, today_mission: @secret_battle)
      goal = @user.strategy_goals.find_by!(horizon: "goal")
      goal.update!(title: @secret_goal)

      health = Today::BattlefieldHealth::Result.new(
        hp: 100,
        done_count: 1,
        total_count: 1,
        open_count: 0,
        band: :neutral,
        risk_icon: "✓",
        risk_note: "",
        result_title: ""
      )
      finale = Today::FinaleMoment.present_for!(
        user: @user,
        health: health,
        goal_title: @secret_goal,
        camp: { camp_current: 1, camp_count: 2, percent: 50 }
      )
      assert finale

      html = ApplicationController.render(
        partial: "dashboard/today_finale",
        locals: { finale: finale },
        assigns: { current_user: @user }
      )
      node = Nokogiri::HTML.fragment(html).at_css(".lp-today-finale")
      share_attr = node["data-today-finale-share-text-value"].to_s
      assert_equal I18n.t("dash.finale.share_text"), share_attr
      refute_includes share_attr, @secret_goal
      assert_includes share_attr, "lifeclimb.app"
    end
  end
end