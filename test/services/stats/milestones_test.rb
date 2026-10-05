# frozen_string_literal: true

require "test_helper"

module Stats
  class MilestonesTest < ActiveSupport::TestCase
    setup do
      @user = users(:one)
      @user.create_notification_preference!(time_zone: "UTC") unless @user.notification_preference
    end

    test "display omits lp and adventure guide and shows next locked badges" do
      journey = seed_climb!(@user, today_mission: "One win")
      battle = @user.strategy_goals.find_by!(horizon: "day", title: "One win")
      battle.update!(completed_at: Time.current)
      battle_wins = Stats::BattleWins.call(user: @user, journey: journey)
      summary = Progress::Dashboard.call(user: @user, period: "7d")[:mountain_summary]
      goal = @user.strategy_goals.for_kind("goal").roots.first

      badges = Stats::Milestones.call(
        user: @user,
        battle_wins: battle_wins,
        mountain_summary: summary,
        strategy_goal: goal,
        any_finished_path_camp: false,
        any_completed_journey: false
      )

      keys = badges.map { |badge| badge[:key] }
      assert_includes keys, "first_battle"
      assert_not_includes keys, "lp_100"
      assert_not_includes keys, "lp_1000"
      assert_not_includes keys, "adventure_guide"
      assert_operator badges.count { |badge| !badge[:unlocked] }, :<=, 2
    end

    test "first camp and summit badges stay earned with completed journey and empty current camps" do
      journey = seed_climb!(@user, today_mission: "Win")
      battle_wins = Stats::BattleWins.call(user: @user, journey: journey)
      summary = {
        projects_done: 0,
        projects_total: 1
      }
      goal = @user.strategy_goals.for_kind("goal").roots.first

      badges = Stats::Milestones.call(
        user: @user,
        battle_wins: battle_wins,
        mountain_summary: summary,
        strategy_goal: goal,
        any_finished_path_camp: true,
        any_completed_journey: true
      )

      keys = badges.select { |b| b[:unlocked] }.map { |b| b[:key] }
      assert_includes keys, "first_camp"
      assert_includes keys, "closer_100"
    end
  end
end
