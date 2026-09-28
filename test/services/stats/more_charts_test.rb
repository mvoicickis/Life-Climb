# frozen_string_literal: true

require "test_helper"

module Stats
  class MoreChartsTest < ActiveSupport::TestCase
    include ClimbTestHelper

    setup do
      enable_habits!
      @user = users(:one)
      @user.daily_todos.delete_all
      @zone = "Europe/Berlin"
      @user.create_notification_preference!(time_zone: @zone) unless @user.notification_preference
      @user.notification_preference.update!(time_zone: @zone)
    end

    test "battle win buckets by local week not utc midnight bleed" do
      travel_to Time.find_zone!(@zone).local(2026, 8, 10, 12, 0, 0) do
        seed_climb!(@user, today_mission: "Monday win")
        battle = @user.strategy_goals.find_by!(horizon: "day", title: "Monday win")
        battle.update!(completed_at: Time.find_zone!(@zone).local(2026, 8, 10, 0, 30, 0))

        charts = MoreCharts.call(user: @user)
        weekly = charts[:weekly][:battles][:points]
        assert_equal 1, weekly.last
        assert charts[:weekly][:battles][:x_labels].any? { |label| label.match?(/Aug/) }
        assert charts[:weekly][:battles][:x_labels].none? { |label| label.start_with?("W") }
      end
    end

    test "completed camp counts until reopened" do
      travel_to Time.find_zone!(@zone).local(2026, 8, 10, 12, 0, 0) do
        journey = @user.primary_focused_journey || seed_climb!(@user, today_mission: "Camp stat")
        journey = @user.reload.primary_focused_journey
        area = journey.life_area
        goal = @user.strategy_goals.for_area(area.id).for_kind("goal").roots.first
        plan = goal.children.find { |c| c.plan? && !c.holding? }
        project = @user.strategy_goals.create!(
          life_area: area,
          life_journey: journey,
          parent: plan,
          horizon: "project",
          title: "Finish me",
          position: 50
        )
        project.complete!

        charts = MoreCharts.call(user: @user, journey: journey)
        assert_equal 1, charts[:weekly][:camps][:points].last

        project.reopen!
        charts_after = MoreCharts.call(user: @user, journey: journey)
        assert_equal 0, charts_after[:weekly][:camps][:points].last
      end
    end

    test "yes no basic counts completion days and countable sums amounts" do
      travel_to Time.find_zone!(@zone).local(2026, 8, 10, 12, 0, 0) do
        journey = @user.primary_focused_journey || seed_climb!(@user, today_mission: "Basics")
        journey = @user.reload.primary_focused_journey
        today = Date.new(2026, 8, 10)

        yes_habit = @user.habits.create!(
          name: "Morning walk",
          unit: "times",
          points: 5,
          frequency: "daily",
          life_journey_id: journey.id,
          quantity_checkin: false
        )
        qty_habit = @user.habits.create!(
          name: "Read",
          unit: "pages",
          points: 5,
          frequency: "daily",
          life_journey_id: journey.id,
          quantity_checkin: true
        )
        yes_habit.completions.create!(user: @user, completed_on: today)
        qty_habit.daily_logs.create!(user: @user, logged_on: today, amount: 8)

        charts = MoreCharts.call(user: @user, journey: journey)
        yes_row = charts[:daily][:habits].find { |row| row[:habit_name] == "Morning walk" }
        qty_row = charts[:daily][:habits].find { |row| row[:habit_name] == "Read" }
        assert_equal 1, yes_row[:points].sum
        assert_equal 8, qty_row[:points].sum
        assert_equal false, yes_row[:countable]
        assert_equal true, qty_row[:countable]
      end
    end

    test "call uses bounded queries" do
      travel_to Time.find_zone!(@zone).local(2026, 8, 10, 12, 0, 0) do
        seed_climb!(@user, today_mission: "Query bound")
        journey = @user.reload.primary_focused_journey
        @user.habits.create!(
          name: "Water",
          unit: "times",
          points: 5,
          frequency: "daily",
          life_journey_id: journey.id
        )

        MoreCharts.call(user: @user, journey: journey)

        queries = 0
        callback = lambda do |_name, _start, _finish, _id, payload|
          next if payload[:cached]
          next if payload[:name] == "SCHEMA" || payload[:name] == "TRANSACTION"

          queries += 1 if payload[:sql].present?
        end

        ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
          MoreCharts.call(user: @user, journey: journey)
        end

        assert_operator queries, :<=, 18, "expected batched queries, got #{queries}"
      end
    end
  end
end
