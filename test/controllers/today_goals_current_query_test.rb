# frozen_string_literal: true

require "test_helper"

class TodayGoalsCurrentQueryTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @user.update!(character: "fox", planning_version: 2)
  end

  test "Goals::Current does not add extra queries when a second journey exists" do
    Onboarding::Bootstrap.call(
      user: @user,
      goal_title: "Single",
      camp_titles: [ "Camp" ]
    )
    journey_a = @user.reload.primary_focused_journey
    area = journey_a.life_area

    count_goal_lookup_queries = lambda do
      Goals::Current.clear_cache!(user: @user)
      queries = 0
      callback = lambda do |_name, _start, _finish, _id, payload|
        next if payload[:cached]
        next if payload[:name] == "SCHEMA" || payload[:name] == "TRANSACTION"
        next if payload[:sql].blank?

        sql = payload[:sql]
        next unless sql.include?("life_journeys") || sql.include?("strategy_goals")

        queries += 1
      end

      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        2.times { Goals::Current.call(user: @user.reload) }
      end
      queries
    end

    single = count_goal_lookup_queries.call

    journey_b = Journeys::Create.call(
      user: @user,
      life_area: area,
      title: "Second",
      ideal_scene: "Ideal",
      current_reality: "Now",
      closer_percent: 10
    )
    @user.strategy_goals.create!(
      life_area: area,
      life_journey: journey_b,
      horizon: "goal",
      title: "Second",
      position: 1,
      due_on: Strategy::YearCycle.default_goal_due
    )
    Goals::Current.clear_cache!(user: @user)

    multi = count_goal_lookup_queries.call

    assert_equal single, multi
  end
end
