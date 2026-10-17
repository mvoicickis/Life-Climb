# frozen_string_literal: true

require "test_helper"

module Battles
  class WinsOnLocalDateEverQueryTest < ActiveSupport::TestCase
    setup do
      @user = users(:one)
      @user.daily_todos.delete_all
      @zone = "Europe/Berlin"
      @journey = @user.primary_focused_journey || begin
        Onboarding::Bootstrap.call(user: @user, goal_title: "Climb", camp_titles: [ "Camp" ])
        @user.reload.primary_focused_journey
      end
      @area = @journey.life_area
      goal = @user.strategy_goals.find_by!(horizon: "goal", life_journey_id: @journey.id)
      plan = @user.strategy_goals.find_by!(horizon: "plan", parent_id: goal.id)
      project = @user.strategy_goals.find_by!(horizon: "project", parent_id: plan.id)
      @leaf = practice_leaf_for!(project)
      @user.strategy_goals.battles.update_all(completed_at: nil)
    end

    def count_ever_queries
      queries = 0
      callback = lambda do |_name, _start, _finish, _id, payload|
        next if payload[:cached]
        next if payload[:name] == "SCHEMA" || payload[:name] == "TRANSACTION"
        next if payload[:sql].blank?

        sql = payload[:sql]
        next unless sql.include?("strategy_goals") || sql.include?("daily_todos")

        queries += 1
      end

      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        WinsOnLocalDate.ever?(user: @user)
      end
      queries
    end

    def seed_one_shot_wins(count:)
      @user.strategy_goals.battles.update_all(completed_at: nil)
      count.times do |i|
        @user.strategy_goals.create!(
          life_area: @area,
          life_journey: @journey,
          parent: @leaf,
          horizon: "day",
          title: "Ever query #{i}",
          scheduled_on: Date.new(2026, 1, 10) - i.days,
          position: i,
          completed_at: Time.find_zone!(@zone).local(2026, 1, 10 + i, 9, 0, 0)
        )
      end
    end

    test "ever? query count is unchanged for one win vs many wins" do
      travel_to Time.find_zone!(@zone).local(2026, 8, 6, 12, 0, 0) do
        @user.update!(created_at: Time.find_zone!(@zone).local(2020, 1, 1, 0, 0, 0))
        seed_one_shot_wins(count: 1)
        single = count_ever_queries

        seed_one_shot_wins(count: 12)
        many = count_ever_queries

        assert_equal single, many, "expected exists? lookup, got single=#{single} many=#{many}"
      end
    end
  end
end
