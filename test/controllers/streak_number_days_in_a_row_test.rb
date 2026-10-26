# frozen_string_literal: true

require "test_helper"

class StreakNumberDaysInARowTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.daily_todos.delete_all
    @user.strategy_goals.delete_all
    @zone = "Europe/Berlin"
    @user.create_notification_preference!(time_zone: @zone) unless @user.notification_preference
    @user.notification_preference.update!(time_zone: @zone)
    # Climb::Streak leftover must not drive the shown number.
    @user.update!(climb_streak_days: 99, climb_streak_on: Date.current, character: "fox", total_points: 10)
    sign_in_as @user
    @today = Date.new(2026, 8, 6)
  end

  test "Today hero fire shows DaysInARow after two local battle wins" do
    travel_to zone_time(2026, 8, 6, 12) do
      seed_two_local_battle_wins!

      get dashboard_path
      assert_response :success
      assert_select ".lp-dash-hero__stat.is-fire span", text: "2"
      assert_select ".lp-dash-hero__stat.is-fire span", text: "99", count: 0
    end
  end

  test "Mountain streak chip shows DaysInARow after two local battle wins" do
    travel_to zone_time(2026, 8, 6, 12) do
      journey = seed_two_local_battle_wins!
      goal = @user.strategy_goals.find_by!(horizon: "goal")

      get life_journey_path(journey, goal_id: goal.id)
      assert_response :success
      assert_select ".lp-rpg-chip.is-streak .lp-rpg-chip__value", text: /2/
      assert_select ".lp-rpg-chip.is-streak", text: /99/, count: 0
    end
  end

  test "Today hero fire stays hidden when only a Basic is done" do
    travel_to zone_time(2026, 8, 6, 12) do
      seed_climb!(@user, today_mission: "Unused")
      habit = habits(:one)
      habit.update!(user: @user)
      habit.daily_logs.create!(user: @user, logged_on: @today, amount: 1)

      get dashboard_path
      assert_response :success
      assert_select ".lp-dash-hero__stat.is-fire", count: 0
    end
  end

  private

  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: "password12345" }
  end

  def zone_time(year, month, day, hour)
    Time.find_zone!(@zone).local(year, month, day, hour, 0, 0)
  end

  def seed_two_local_battle_wins!
    journey = seed_climb!(@user, today_mission: "Today win")
    project = @user.strategy_goals.find_by!(horizon: "project", title: "Auth")
    complete_one_shot!(project, journey, "Yesterday win", on: @today - 1)
    complete_one_shot!(project, journey, "Today win", on: @today)
    assert_equal 2, Battles::DaysInARow.count(user: @user)
    journey
  end

  def complete_one_shot!(project, journey, title, on:)
    battle = project.children.find_by(horizon: "day", title: title)
    battle ||= project.children.create!(
      user: @user,
      life_area: journey.life_area,
      life_journey: journey,
      horizon: "day",
      title: title,
      scheduled_on: on,
      position: project.children.count
    )
    battle.update!(completed_at: zone_time(on.year, on.month, on.day, 9))
    battle
  end
end
