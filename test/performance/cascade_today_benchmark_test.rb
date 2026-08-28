# frozen_string_literal: true

require "test_helper"

class CascadeTodayBenchmarkTest < ActiveSupport::TestCase
  include ClimbTestHelper

  setup do
    @user = users(:one)
    @area = life_areas(:one_self)
    @goal = @user.strategy_goals.create!(life_area: @area, horizon: "goal", title: "Bench Goal", position: 0)
    @plan = @user.strategy_goals.create!(
      life_area: @area, parent: @goal, horizon: "plan", title: "Bench Plan", position: 0
    )
    @camp = @user.strategy_goals.create!(
      life_area: @area, parent: @plan, horizon: "project", title: "Bench Camp", position: 0
    )
    @camp_leaf = practice_leaf_for!(@camp)
  end

  test "benchmark cascade plus waiting count for 5 20 and 35 open battles" do
    skip "Set RUN_CASCADE_BENCHMARK=1 to print timings" unless ENV["RUN_CASCADE_BENCHMARK"] == "1"

    [ 5, 20, 35 ].each do |battle_count|
      user = duplicate_user_with_battles!(battle_count)
      area = user.life_areas.first
      queries = 0
      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*_, payload|
        queries += 1 unless %w[SCHEMA TRANSACTION].include?(payload[:name])
      end

      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      Strategy::CascadeToDaily.call(user: user, life_area: area, from: Date.current, to: Date.current)
      waiting = Today::BattlesWaiting.count(user: user, life_area: area, on: Date.current)
      elapsed_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000.0
      ActiveSupport::Notifications.unsubscribe(subscriber)

      surfaced = user.daily_todos.for_day(Date.current).count
      puts "#{battle_count} battles: #{queries} queries, #{elapsed_ms.round(1)}ms " \
           "(surfaced #{surfaced}, waiting #{waiting})"
      assert queries.positive?
    end
  end

  private

  def duplicate_user_with_battles!(battle_count)
    user = User.create!(
      name: "Bench #{battle_count}",
      email_address: "bench-#{battle_count}-#{SecureRandom.hex(4)}@example.test",
      password: "password12345",
      password_confirmation: "password12345",
      planning_version: 2,
      character: "fox"
    )
    area = user.life_areas.create!(key: "career", number: 1, position: 0)
    user.life_journeys.create!(
      life_area: area, title: "Bench", status: "active", focus_position: 1,
      ideal_scene: "Done", current_reality: "Building"
    )
    goal = user.strategy_goals.create!(life_area: area, horizon: "goal", title: "Goal", position: 0)
    plan = user.strategy_goals.create!(life_area: area, parent: goal, horizon: "plan", title: "Plan", position: 0)
    camp = user.strategy_goals.create!(life_area: area, parent: plan, horizon: "project", title: "Camp", position: 0)

    battle_count.times do |i|
      user.strategy_goals.create!(
        life_area: area, parent: camp, horizon: "day",
        title: "Battle #{i}", scheduled_on: 1.month.from_now.to_date, repeat: "none", position: i
      )
    end

    user
  end
end
