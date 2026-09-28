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
        strategy_goal: goal
      )

      keys = badges.map { |badge| badge[:key] }
      assert_includes keys, "first_battle"
      assert_not_includes keys, "lp_100"
      assert_not_includes keys, "lp_1000"
      assert_not_includes keys, "adventure_guide"
      assert_operator badges.count { |badge| !badge[:unlocked] }, :<=, 2
    end
  end
end
