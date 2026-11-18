# frozen_string_literal: true

require "test_helper"

module Admin
  class TestersDailyClimbersTest < ActiveSupport::TestCase
    setup do
      @zone = Testers::DAY_ZONE
      @admin = users(:admin)
      @user = users(:one)
      @other = users(:two)
      @month = Date.new(2026, 11, 1)
      @day = Date.new(2026, 11, 18)
    end

    test "one-shot and recurring wins count unique testers per Berlin day" do
      travel_to Time.find_zone!(@zone).local(2026, 11, 18, 12, 0, 0) do
        plant_one_shot_win!(@user, at: Time.find_zone!(@zone).local(2026, 11, 18, 9, 0, 0))
        plant_recurring_win!(@other, on: @day)

        counts = Testers.counts_by_day(month: @month)
        assert_equal 2, counts[@day][:testers]
        assert_equal 0, counts[@day][:admins]
      end
    end

    test "same user winning twice on one day counts once" do
      travel_to Time.find_zone!(@zone).local(2026, 11, 18, 12, 0, 0) do
        plant_one_shot_win!(@user, at: Time.find_zone!(@zone).local(2026, 11, 18, 9, 0, 0))
        plant_one_shot_win!(@user, at: Time.find_zone!(@zone).local(2026, 11, 18, 15, 0, 0), title: "Second win")
        plant_recurring_win!(@user, on: @day)

        counts = Testers.counts_by_day(month: @month)
        assert_equal 1, counts[@day][:testers]
      end
    end

    test "Berlin midnight edge puts 23:30 and 00:30 on different days" do
      travel_to Time.find_zone!(@zone).local(2026, 11, 18, 12, 0, 0) do
        plant_one_shot_win!(
          @user,
          at: Time.find_zone!(@zone).local(2026, 11, 17, 23, 30, 0),
          title: "Late evening"
        )
        plant_one_shot_win!(
          @other,
          at: Time.find_zone!(@zone).local(2026, 11, 18, 0, 30, 0),
          title: "Just after midnight"
        )

        counts = Testers.counts_by_day(month: @month)
        assert_equal 1, counts[Date.new(2026, 11, 17)][:testers]
        assert_equal 1, counts[Date.new(2026, 11, 18)][:testers]
      end
    end

    test "privileged users only appear in admins count" do
      travel_to Time.find_zone!(@zone).local(2026, 11, 18, 12, 0, 0) do
        plant_one_shot_win!(@user, at: Time.find_zone!(@zone).local(2026, 11, 18, 9, 0, 0))
        plant_one_shot_win!(@admin, at: Time.find_zone!(@zone).local(2026, 11, 18, 10, 0, 0))

        counts = Testers.counts_by_day(month: @month)
        assert_equal 1, counts[@day][:testers]
        assert_equal 1, counts[@day][:admins]
      end
    end

    test "goal_tier colors by threshold" do
      assert_equal :zero, Testers.goal_tier(0)
      assert_equal :partial, Testers.goal_tier(1)
      assert_equal :partial, Testers.goal_tier(Testers::DAILY_CLIMBERS_GOAL - 1)
      assert_equal :met, Testers.goal_tier(Testers::DAILY_CLIMBERS_GOAL)
      assert_equal :met, Testers.goal_tier(Testers::DAILY_CLIMBERS_GOAL + 3)
    end

    test "query count stays flat as win rows grow" do
      travel_to Time.find_zone!(@zone).local(2026, 11, 18, 12, 0, 0) do
        plant_one_shot_win!(@user, at: Time.find_zone!(@zone).local(2026, 11, 18, 9, 0, 0))
        one_count = count_queries { Testers.counts_by_day(month: @month) }

        8.times do |index|
          climber = User.create!(
            email_address: "climber-#{index}-#{SecureRandom.hex(3)}@example.com",
            name: "Climber #{index}",
            password: "password12345",
            password_confirmation: "password12345",
            onboarding_completed_at: 2.weeks.ago
          )
          plant_one_shot_win!(
            climber,
            at: Time.find_zone!(@zone).local(2026, 11, 10 + (index % 8), 11, 0, 0),
            title: "Bulk win #{index}"
          )
        end

        many_count = count_queries { Testers.counts_by_day(month: @month) }
        assert_equal one_count, many_count
        assert_operator one_count, :<=, 5
      end
    end

    private

    def plant_one_shot_win!(user, at:, title: "Daily goal win")
      journey = user.primary_focused_journey || seed_climb!(user, today_mission: title)
      camp = user.strategy_goals.where(horizon: "project", life_journey_id: journey.id).order(:id).last
      battle = user.strategy_goals.battles.find_by(title: title)
      battle ||= add_todays_battle!(user: user, project: camp, journey: journey, title: title)
      battle.update!(completed_at: at, repeat: nil, scheduled_on: at.in_time_zone(@zone).to_date)
      battle
    end

    def plant_recurring_win!(user, on:)
      title = "Daily stretch #{SecureRandom.hex(2)}"
      journey = user.primary_focused_journey || seed_climb!(user, today_mission: title)
      camp = user.strategy_goals.where(horizon: "project", life_journey_id: journey.id).order(:id).last
      battle = add_todays_battle!(user: user, project: camp, journey: journey, title: title)
      battle.update!(repeat: "daily", completed_at: nil)
      Strategy::CascadeToDaily.call(user: user, life_area: battle.life_area, from: on, to: on)
      todo = user.daily_todos.for_day(on).find_by!(strategy_goal_id: battle.id)
      todo.update!(completed_at: Time.find_zone!(@zone).local(on.year, on.month, on.day, 10, 0, 0))
      todo
    end

    def count_queries
      queries = 0
      callback = lambda do |_name, _start, _finish, _id, payload|
        next if payload[:name] == "SCHEMA" || payload[:name] == "TRANSACTION"

        queries += 1 if payload[:sql].present?
      end

      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        yield
      end
      queries
    end
  end
end
