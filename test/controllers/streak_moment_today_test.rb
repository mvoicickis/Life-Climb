# frozen_string_literal: true

require "test_helper"

class StreakMomentTodayTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.daily_todos.delete_all
    sign_in_as @user
    @zone = "Europe/Berlin"
    @user.create_notification_preference!(time_zone: @zone) unless @user.notification_preference
    @user.notification_preference.update!(time_zone: @zone)
    @user.update!(last_streak_moment_on: nil) if @user.has_attribute?(:last_streak_moment_on)
    @today = Date.new(2026, 8, 6)
  end

  test "today visit after mountain win shows streak moment once" do
    travel_to Time.find_zone!(@zone).local(2026, 8, 6, 12, 0, 0) do
      seed_climb!(@user, today_mission: "Today win")
      project = @user.strategy_goals.find_by!(horizon: "project", title: "Auth")
      journey = @user.primary_focused_journey
      yesterday = project.children.create!(
        user: @user,
        life_area: journey.life_area,
        life_journey: journey,
        horizon: "day",
        title: "Yesterday win",
        scheduled_on: @today - 1,
        position: 1,
        completed_at: Time.find_zone!(@zone).local(2026, 8, 5, 9, 0, 0)
      )
      assert yesterday.completed_at?

      today_battle = project.children.find_by!(horizon: "day", title: "Today win")
      today_battle.update!(completed_at: Time.find_zone!(@zone).local(2026, 8, 6, 9, 0, 0))

      get dashboard_path
      assert_response :success
      assert_select ".lp-streak-moment"
      assert_select ".lp-streak-moment__num.is-to", text: "2"
      assert_equal @today, @user.reload.last_streak_moment_on

      get dashboard_path
      assert_response :success
      assert_select ".lp-streak-moment", count: 0
    end
  end

  test "Monday streak strip shows Sunday and Monday wins with today last" do
    monday = Date.new(2026, 8, 10)
    sunday = monday - 1
    travel_to Time.find_zone!(@zone).local(2026, 8, 10, 12, 0, 0) do
      @user.update!(last_streak_moment_on: nil) if @user.has_attribute?(:last_streak_moment_on)
      seed_climb!(@user, today_mission: "Monday win")
      project = @user.strategy_goals.find_by!(horizon: "project", title: "Auth")
      journey = @user.primary_focused_journey
      project.children.create!(
        user: @user,
        life_area: journey.life_area,
        life_journey: journey,
        horizon: "day",
        title: "Sunday win",
        scheduled_on: sunday,
        position: 1,
        completed_at: Time.find_zone!(@zone).local(2026, 8, 9, 9, 0, 0)
      )
      project.children.find_by!(horizon: "day", title: "Monday win")
        .update!(completed_at: Time.find_zone!(@zone).local(2026, 8, 10, 9, 0, 0))

      get dashboard_path
      assert_response :success
      assert_select ".lp-streak-moment__week .lp-streak-moment__day", count: 7
      assert_select ".lp-streak-moment__week .lp-streak-moment__day-mark.is-won", count: 2
      assert_select ".lp-streak-moment__week .lp-streak-moment__day.is-today", count: 1
      assert_select ".lp-streak-moment__week .lp-streak-moment__day:last-child.is-today"
      assert_select ".lp-streak-moment__week .lp-streak-moment__day:last-child .lp-streak-moment__day-mark.is-won"
      assert_select ".lp-streak-moment__week .lp-streak-moment__day:nth-child(6) .lp-streak-moment__day-mark.is-won"
    end
  end
end
