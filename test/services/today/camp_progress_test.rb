# frozen_string_literal: true

require "test_helper"

class Today::CampProgressTest < ActiveSupport::TestCase
  include ClimbTestHelper

  setup do
    @user = users(:one)
    @journey = seed_climb!(@user, today_mission: "Ship auth")
    @goal = @user.strategy_goals.for_kind("goal").roots.find_by!(life_journey_id: @journey.id)
    @camp = Strategy::PathProject.resolve(user: @user, journey: @journey)
    assert @camp.present?
  end

  test "returns nil when there is no current camp" do
    @user.strategy_goals.where(horizon: "project", life_journey_id: @journey.id).find_each do |camp|
      camp.update_columns(completed_at: Time.current)
    end

    assert_nil Strategy::PathProject.resolve(user: @user, journey: @journey.reload)
    assert_nil Today::CampProgress.call(user: @user, journey: @journey, goal: @goal)
  end

  test "zero battles yields won 0 total 0 percent 0" do
    @camp.children.where(horizon: "day").delete_all

    result = Today::CampProgress.call(user: @user, journey: @journey, goal: @goal)

    assert_equal @camp.id, result[:camp_id]
    assert_equal @camp.title, result[:camp_title]
    assert_equal 0, result[:won]
    assert_equal 0, result[:total]
    assert_equal 0, result[:percent]
  end

  test "one of five battles won is 20 percent" do
    @camp.children.where(horizon: "day").delete_all
    battles = 5.times.map do |i|
      @camp.children.create!(
        user: @user,
        life_area: @journey.life_area,
        life_journey: @journey,
        horizon: "day",
        title: "Fight #{i}",
        scheduled_on: Date.current + i.days,
        position: i
      )
    end
    battles.first.update!(completed_at: Time.current)

    result = Today::CampProgress.call(user: @user, journey: @journey, goal: @goal)

    assert_equal 1, result[:won]
    assert_equal 5, result[:total]
    assert_equal 20, result[:percent]
  end

  test "adding a battle drops percent" do
    @camp.children.where(horizon: "day").delete_all
    first = @camp.children.create!(
      user: @user,
      life_area: @journey.life_area,
      life_journey: @journey,
      horizon: "day",
      title: "Only fight",
      scheduled_on: Date.current,
      position: 0
    )
    first.update!(completed_at: Time.current)

    before = Today::CampProgress.call(user: @user, journey: @journey, goal: @goal)
    assert_equal 100, before[:percent]
    assert_equal 1, before[:total]

    @camp.children.create!(
      user: @user,
      life_area: @journey.life_area,
      life_journey: @journey,
      horizon: "day",
      title: "Extra fight",
      scheduled_on: Date.current + 1.day,
      position: 1
    )

    after = Today::CampProgress.call(user: @user, journey: @journey, goal: @goal)
    assert_equal 1, after[:won]
    assert_equal 2, after[:total]
    assert_equal 50, after[:percent]
    assert_operator after[:percent], :<, before[:percent]
  end

  test "finished camp reads 100 percent" do
    @camp.children.where(horizon: "day").delete_all
    open_battle = @camp.children.create!(
      user: @user,
      life_area: @journey.life_area,
      life_journey: @journey,
      horizon: "day",
      title: "Still open",
      scheduled_on: Date.current,
      position: 0
    )
    assert_nil open_battle.completed_at
    @camp.update_columns(completed_at: Time.current)

    Strategy::PathProject.stub(:resolve, @camp) do
      result = Today::CampProgress.call(user: @user, journey: @journey, goal: @goal)
      assert_equal 100, result[:percent]
      assert_equal @camp.id, result[:camp_id]
    end
  end

  test "another users camp is never returned" do
    other = users(:two)
    other_journey = seed_climb!(other, today_mission: "Other fight", title: "Other climb")
    other_goal = other.strategy_goals.for_kind("goal").roots.find_by!(life_journey_id: other_journey.id)
    other_camp = Strategy::PathProject.resolve(user: other, journey: other_journey)
    assert other_camp.present?

    result = Today::CampProgress.call(user: @user, journey: other_journey, goal: other_goal)
    assert_nil result

    result = Today::CampProgress.call(user: @user, journey: @journey, goal: other_goal)
    assert_nil result
  end

  test "query count stays flat from few battles to many" do
    @camp.children.where(horizon: "day").delete_all

    count_queries = lambda do
      queries = 0
      callback = lambda do |_name, _start, _finish, _id, payload|
        next if payload[:cached]
        next if payload[:name] == "SCHEMA" || payload[:name] == "TRANSACTION"

        queries += 1 if payload[:sql].present?
      end

      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        Today::CampProgress.call(user: @user, journey: @journey, goal: @goal)
      end
      queries
    end

    3.times do |i|
      @camp.children.create!(
        user: @user,
        life_area: @journey.life_area,
        life_journey: @journey,
        horizon: "day",
        title: "Short #{i}",
        scheduled_on: Date.current + i.days,
        position: i
      )
    end
    short_queries = count_queries.call

    27.times do |i|
      @camp.children.create!(
        user: @user,
        life_area: @journey.life_area,
        life_journey: @journey,
        horizon: "day",
        title: "Long #{i}",
        scheduled_on: Date.current + (i + 10).days,
        position: i + 10
      )
    end
    assert_equal 30, Strategy::BattleIdsByProject.call(
      user: @user, journey: @journey, projects: [ @camp ]
    )[@camp.id].size

    long_queries = count_queries.call

    assert_equal short_queries, long_queries,
                 "expected batched queries (3 battles=#{short_queries}, 30 battles=#{long_queries})"
  end
end
