# frozen_string_literal: true

require "test_helper"

# Live Mountain is the v4 trail (no rpg_goal_switcher). These tests cover the
# two SHOW readers this PR switched: dash_hero + rpg_goal_switcher partials,
# plus DaysInARow as the number source.
class StreakNumberDaysInARowTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.daily_todos.delete_all
    @user.strategy_goals.delete_all
    @zone = "Europe/Berlin"
    @user.create_notification_preference!(time_zone: @zone) unless @user.notification_preference
    @user.notification_preference.update!(time_zone: @zone)
    @user.update!(climb_streak_days: 99, climb_streak_on: Date.current, character: "fox")
    @today = Date.new(2026, 8, 6)
  end

  test "DaysInARow is two after local battle wins and ignores Basics and Climb::Streak" do
    travel_to zone_time(2026, 8, 6, 12) do
      journey = seed_climb!(@user, today_mission: "Today win")
      project = @user.strategy_goals.find_by!(horizon: "project", title: "Auth")
      complete_one_shot!(project, journey, "Yesterday win", on: @today - 1)
      complete_one_shot!(project, journey, "Today win", on: @today)

      assert_equal 2, Battles::DaysInARow.count(user: @user)
      assert_equal 99, @user.climb_streak_days
    end
  end

  test "DaysInARow stays zero when only a Basics log exists" do
    travel_to zone_time(2026, 8, 6, 12) do
      seed_climb!(@user, today_mission: "Unused")
      habit = habits(:one)
      habit.update!(user: @user)
      habit.daily_logs.create!(user: @user, logged_on: @today, amount: 1)

      assert_equal 0, Battles::DaysInARow.count(user: @user)
    end
  end

  private

  def zone_time(year, month, day, hour)
    Time.find_zone!(@zone).local(year, month, day, hour, 0, 0)
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

class DashHeroBattleDaysTest < ActionView::TestCase
  include ApplicationHelper

  def current_user
    @user
  end

  setup do
    @user = users(:one)
    @user.update!(character: "fox", climb_streak_days: 99, climb_streak_on: Date.current)
  end

  test "hero fire shows battle days and hides at zero" do
    render partial: "dashboard/dash_hero",
           locals: {
             day_percent: 40,
             habits_count: 0,
             battles_count: 0,
             life_points: 10,
             battle_days: 0,
             commitment: nil,
             journey: nil
           }

    assert_select ".lp-dash-hero__stat.is-fire", count: 0

    render partial: "dashboard/dash_hero",
           locals: {
             day_percent: 40,
             habits_count: 0,
             battles_count: 1,
             life_points: 10,
             battle_days: 2,
             commitment: nil,
             journey: nil
           }

    assert_select ".lp-dash-hero__stat.is-fire span", text: "2"
    assert_select ".lp-dash-hero__stat.is-fire span", text: "99", count: 0
  end
end

class RpgGoalSwitcherBattleDaysTest < ActionView::TestCase
  include ApplicationHelper

  def current_user
    @user
  end

  setup do
    @user = users(:one)
    @user.update!(character: "fox", climb_streak_days: 99, climb_streak_on: Date.current, total_points: 10)
  end

  test "Mountain HUD chip shows battle days and hides at zero" do
    render partial: "life_journeys/rpg_goal_switcher",
           locals: {
             root_goals: [],
             goal: nil,
             progress: 0,
             mountain: {},
             alive: @user.alive_level,
             battle_days: 0
           }

    assert_select ".lp-rpg-chip.is-streak", count: 0

    render partial: "life_journeys/rpg_goal_switcher",
           locals: {
             root_goals: [],
             goal: nil,
             progress: 0,
             mountain: {},
             alive: @user.alive_level,
             battle_days: 2
           }

    assert_select ".lp-rpg-chip.is-streak .lp-rpg-chip__value", text: /2/
    assert_select ".lp-rpg-chip.is-streak", text: /99/, count: 0
  end
end
