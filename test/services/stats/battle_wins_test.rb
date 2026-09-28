# frozen_string_literal: true

require "test_helper"

module Stats
  class BattleWinsTest < ActiveSupport::TestCase
    setup do
      @user = users(:one)
      @user.daily_todos.delete_all
      @zone = "Europe/Berlin"
      @user.create_notification_preference!(time_zone: @zone) unless @user.notification_preference
      @user.notification_preference.update!(time_zone: @zone)
      @date = Date.new(2026, 8, 6)
    end

    test "one-shot completed on local date counts toward all time and that day" do
      travel_to Time.find_zone!(@zone).local(2026, 8, 6, 12, 0, 0) do
        seed_climb!(@user, today_mission: "Ship auth")
        battle = @user.strategy_goals.find_by!(horizon: "day", title: "Ship auth")
        battle.update!(completed_at: Time.find_zone!(@zone).local(2026, 8, 6, 9, 0, 0))

        stats = BattleWins.call(user: @user)
        assert_equal 1, stats.all_time_total
        assert_equal 1, stats.counts_by_date(from: @date, to: @date)[@date]
      end
    end

    test "one-shot completed on earlier local day does not count on target day" do
      travel_to Time.find_zone!(@zone).local(2026, 8, 6, 12, 0, 0) do
        seed_climb!(@user, today_mission: "Yesterday win")
        battle = @user.strategy_goals.find_by!(horizon: "day", title: "Yesterday win")
        battle.update!(completed_at: Time.find_zone!(@zone).local(2026, 8, 5, 9, 0, 0))

        stats = BattleWins.call(user: @user)
        assert_equal 0, stats.counts_by_date(from: @date, to: @date)[@date].to_i
        assert_equal 1, stats.counts_by_date(from: Date.new(2026, 8, 5), to: Date.new(2026, 8, 5))[Date.new(2026, 8, 5)]
      end
    end

    test "daily battle todo on scheduled_on counts as win" do
      travel_to Time.find_zone!(@zone).local(2026, 8, 6, 12, 0, 0) do
        seed_climb!(@user, today_mission: "Stretch daily")
        battle = @user.strategy_goals.find_by!(horizon: "day", title: "Stretch daily")
        battle.update!(repeat: "daily")
        Strategy::CascadeToDaily.call(user: @user, life_area: battle.life_area, from: @date, to: @date)
        todo = @user.daily_todos.for_day(@date).find_by!(strategy_goal_id: battle.id)
        todo.update!(completed_at: Time.find_zone!(@zone).local(2026, 8, 6, 10, 0, 0))

        stats = BattleWins.call(user: @user)
        assert_equal 1, stats.counts_by_date(from: @date, to: @date)[@date]
      end
    end

    test "ad-hoc todo without strategy link does not count" do
      travel_to Time.find_zone!(@zone).local(2026, 8, 6, 12, 0, 0) do
        @user.daily_todos.create!(
          title: "Personal errand",
          aspect_key: "career",
          scheduled_on: @date,
          position: 0,
          completed_at: Time.find_zone!(@zone).local(2026, 8, 6, 10, 0, 0)
        )

        stats = BattleWins.call(user: @user)
        assert_equal 0, stats.all_time_total
      end
    end

    test "best_weekday hidden when last 28 days total is under 5" do
      travel_to Time.find_zone!(@zone).local(2026, 8, 28, 12, 0, 0) do
        seed_climb!(@user, today_mission: "Only one")
        battle = @user.strategy_goals.find_by!(horizon: "day", title: "Only one")
        battle.update!(completed_at: Time.find_zone!(@zone).local(2026, 8, 27, 9, 0, 0))

        stats = BattleWins.call(user: @user)
        assert_nil stats.best_weekday
      end
    end

    test "best_weekday returns weekday name when last 28 days has enough wins" do
      travel_to Time.find_zone!(@zone).local(2026, 8, 31, 12, 0, 0) do
        seed_climb!(@user, today_mission: "Win one")
        journey = @user.primary_focused_journey
        area = journey.life_area
        project = @user.strategy_goals.find_by!(horizon: "project", title: "Auth")
        monday = Date.new(2026, 8, 10)

        5.times do |i|
          title = i.zero? ? "Win one" : "Extra #{i}"
          battle =
            if i.zero?
              project.children.find_by!(horizon: "day", title: title)
            else
              project.children.create!(
                user: @user,
                life_area: area,
                life_journey: journey,
                horizon: "day",
                title: title,
                scheduled_on: monday,
                position: i
              )
            end
          battle.update!(completed_at: Time.find_zone!(@zone).local(monday.year, monday.month, monday.day, 9 + i, 0, 0))
        end

        stats = BattleWins.call(user: @user, journey: journey)
        assert_operator stats.counts_by_date(from: monday, to: Date.new(2026, 8, 31)).values.sum, :>=, 5
        assert_equal "Monday", stats.best_weekday
      end
    end

    test "by_camp attributes wins to project and omits zero camps" do
      travel_to Time.find_zone!(@zone).local(2026, 8, 6, 12, 0, 0) do
        journey = seed_climb!(@user, today_mission: "Camp battle")
        project = @user.strategy_goals.find_by!(horizon: "project", title: "Auth")
        battle = project.children.find_by!(horizon: "day", title: "Camp battle")
        battle.update!(completed_at: Time.find_zone!(@zone).local(2026, 8, 6, 9, 0, 0))

        stats = BattleWins.call(user: @user, journey: journey)
        rows = stats.by_camp
        assert_equal 1, rows.size
        assert_equal project.id, rows.first[:project_id]
        assert_equal 1, rows.first[:wins]
      end
    end

    test "counts_by_date uses bounded queries across many days" do
      travel_to Time.find_zone!(@zone).local(2026, 8, 15, 12, 0, 0) do
        journey = seed_climb!(@user, today_mission: "One shot win")
        project = @user.strategy_goals.find_by!(horizon: "project", title: "Auth")
        one_shot = @user.strategy_goals.find_by!(horizon: "day", title: "One shot win")
        one_shot.update!(completed_at: Time.find_zone!(@zone).local(2026, 8, 5, 9, 0, 0))

        daily = project.children.create!(
          user: @user,
          life_area: journey.life_area,
          life_journey: journey,
          horizon: "day",
          title: "Daily win",
          scheduled_on: Date.current,
          position: 1,
          repeat: "daily"
        )
        range_from = Date.new(2026, 8, 1)
        range_to = range_from + 59
        Strategy::CascadeToDaily.call(user: @user, life_area: daily.life_area, from: range_from, to: range_to)
        daily_todo = @user.daily_todos.for_day(Date.new(2026, 8, 12)).find_by!(strategy_goal_id: daily.id)
        daily_todo.update!(completed_at: Time.find_zone!(@zone).local(2026, 8, 12, 10, 0, 0))

        stats = BattleWins.call(user: @user)
        stats.time_zone

        count_queries = lambda do |from, to|
          queries = 0
          callback = lambda do |_name, _start, _finish, _id, payload|
            next if payload[:cached]
            next if payload[:name] == "SCHEMA" || payload[:name] == "TRANSACTION"

            queries += 1 if payload[:sql].present?
          end

          ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
            stats.counts_by_date(from: from, to: to)
          end
          queries
        end

        single_day = Date.new(2026, 8, 15)
        one_day_queries = count_queries.call(single_day, single_day)
        wide_queries = count_queries.call(range_from, range_to)

        assert_equal one_day_queries, wide_queries,
                     "expected batched queries (1-day=#{one_day_queries}, 60-day=#{wide_queries})"
      end
    end

    test "calendar_month tiers and days with wins" do
      travel_to Time.find_zone!(@zone).local(2026, 9, 10, 12, 0, 0) do
        stats = BattleWins.call(user: @user)
        calendar = stats.calendar_month(2026, 9)
        assert_equal 2026, calendar[:year]
        assert_equal 9, calendar[:month]
        assert_equal 0, calendar[:days_with_wins]
        assert_equal 0, stats.calendar_tier(0)
        assert_equal 1, stats.calendar_tier(1)
        assert_equal 2, stats.calendar_tier(2)
        assert_equal 3, stats.calendar_tier(4)
      end
    end
  end
end
