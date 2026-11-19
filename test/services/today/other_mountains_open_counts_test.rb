# frozen_string_literal: true

require "test_helper"

class Today::OtherMountainsOpenCountsTest < ActiveSupport::TestCase
  include ClimbTestHelper
  include TodayV2TestHelper

  setup do
    @user = users(:one)
    @zone = "America/Los_Angeles"
    @user.create_notification_preference!(time_zone: @zone) unless @user.notification_preference
    @user.notification_preference.update!(time_zone: @zone)
    allow_extra_climbs!(@user)

    travel_to Time.find_zone!(@zone).local(2026, 8, 6, 12, 0, 0) do
      @today = Battles::WinsOnLocalDate.local_today_for(@user)
      @focused = seed_climb!(@user, area_key: "career", title: "Focused peak", today_mission: "Focused fight")
      dismiss_onboarding_missions!(@user)
    end
  end

  test "excludes the focused journey even when it has open battles" do
    travel_to Time.find_zone!(@zone).local(2026, 8, 6, 12, 0, 0) do
      other = seed_second_journey!(title: "Other peak", area_key: "self", battle_title: "Other fight")

      result = Today::OtherMountainsOpenCounts.call(
        user: @user,
        focused_journey: @focused,
        date: @today
      )

      ids = result.journeys.map(&:journey_id)
      refute_includes ids, @focused.id
      assert_includes ids, other.id
      assert_equal 1, result.journeys.find { |e| e.journey_id == other.id }.open_count
      assert_equal 1, result.total
    end
  end

  test "counts only open battles and ignores won ones" do
    travel_to Time.find_zone!(@zone).local(2026, 8, 6, 12, 0, 0) do
      open_journey = seed_second_journey!(title: "Open peak", area_key: "self", battle_title: "Still open")
      won_journey = seed_second_journey!(title: "Won peak", area_key: "purpose", battle_title: "Already won")
      won = @user.strategy_goals.find_by!(horizon: "day", title: "Already won", life_journey_id: won_journey.id)
      won.update!(completed_at: Time.find_zone!(@zone).local(2026, 8, 6, 9, 0, 0))
      Strategy::CascadeToDaily.call(user: @user, life_area: won_journey.life_area, from: @today, to: @today)
      todo = @user.daily_todos.for_day(@today).find_by(strategy_goal_id: won.id)
      todo&.update!(completed_at: Time.find_zone!(@zone).local(2026, 8, 6, 9, 5, 0))

      result = Today::OtherMountainsOpenCounts.call(
        user: @user,
        focused_journey: @focused,
        date: @today
      )

      ids = result.journeys.map(&:journey_id)
      assert_includes ids, open_journey.id
      refute_includes ids, won_journey.id
      assert_equal 1, result.total
    end
  end

  test "counts recurring and one-shot open battles" do
    travel_to Time.find_zone!(@zone).local(2026, 8, 6, 12, 0, 0) do
      one_shot = seed_second_journey!(title: "One shot peak", area_key: "self", battle_title: "One shot fight")
      recurring = seed_second_journey!(title: "Daily peak", area_key: "purpose", battle_title: "Daily fight")
      daily = @user.strategy_goals.find_by!(horizon: "day", title: "Daily fight", life_journey_id: recurring.id)
      daily.update!(repeat: "daily")
      Strategy::CascadeToDaily.call(user: @user, life_area: recurring.life_area, from: @today, to: @today)

      result = Today::OtherMountainsOpenCounts.call(
        user: @user,
        focused_journey: @focused,
        date: @today
      )

      by_id = result.journeys.index_by(&:journey_id)
      assert_equal 1, by_id[one_shot.id].open_count
      assert_equal 1, by_id[recurring.id].open_count
      assert_equal 2, result.total
    end
  end

  test "excludes ad-hoc todos without a strategy goal" do
    travel_to Time.find_zone!(@zone).local(2026, 8, 6, 12, 0, 0) do
      other = seed_second_journey!(title: "Quiet peak", area_key: "self", battle_title: "Quiet fight")
      battle = @user.strategy_goals.find_by!(horizon: "day", title: "Quiet fight", life_journey_id: other.id)
      battle.update!(completed_at: Time.find_zone!(@zone).local(2026, 8, 6, 8, 0, 0))

      @user.daily_todos.create!(
        title: "Errand",
        aspect_key: "self",
        scheduled_on: @today,
        position: 99,
        lp_reward: 10
      )

      result = Today::OtherMountainsOpenCounts.call(
        user: @user,
        focused_journey: @focused,
        date: @today
      )

      assert_equal [], result.journeys
      assert_equal 0, result.total
    end
  end

  test "omits journeys with zero open battles from the list" do
    travel_to Time.find_zone!(@zone).local(2026, 8, 6, 12, 0, 0) do
      empty = seed_second_journey!(title: "Empty peak", area_key: "self", battle_title: "Done fight")
      battle = @user.strategy_goals.find_by!(horizon: "day", title: "Done fight", life_journey_id: empty.id)
      battle.update!(completed_at: Time.find_zone!(@zone).local(2026, 8, 6, 8, 0, 0))
      live = seed_second_journey!(title: "Live peak", area_key: "purpose", battle_title: "Live fight")

      result = Today::OtherMountainsOpenCounts.call(
        user: @user,
        focused_journey: @focused,
        date: @today
      )

      assert_equal [ live.id ], result.journeys.map(&:journey_id)
      assert_equal 1, result.total
    end
  end

  test "total equals the sum of open counts and sorts by count then title" do
    travel_to Time.find_zone!(@zone).local(2026, 8, 6, 12, 0, 0) do
      alpha = seed_second_journey!(title: "Alpha peak", area_key: "self", battle_title: "Alpha 1")
      alpha_camp = @user.strategy_goals.find_by!(horizon: "project", title: "Camp Alpha peak", life_journey_id: alpha.id)
      alpha_camp.children.create!(
        user: @user, life_area: alpha.life_area, life_journey: alpha,
        horizon: "day", title: "Alpha 2", scheduled_on: @today, position: 1
      )

      bravo = seed_second_journey!(title: "Bravo peak", area_key: "purpose", battle_title: "Bravo 1")
      charlie = seed_second_journey!(title: "Charlie peak", area_key: "money", battle_title: "Charlie 1")
      charlie_camp = @user.strategy_goals.find_by!(horizon: "project", title: "Camp Charlie peak", life_journey_id: charlie.id)
      charlie_camp.children.create!(
        user: @user, life_area: charlie.life_area, life_journey: charlie,
        horizon: "day", title: "Charlie 2", scheduled_on: @today, position: 1
      )

      result = Today::OtherMountainsOpenCounts.call(
        user: @user,
        focused_journey: @focused,
        date: @today
      )

      assert_equal [ alpha.id, charlie.id, bravo.id ], result.journeys.map(&:journey_id)
      assert_equal [ 2, 2, 1 ], result.journeys.map(&:open_count)
      assert_equal 5, result.total
      assert_equal result.journeys.sum(&:open_count), result.total
    end
  end

  test "never includes another users journeys" do
    travel_to Time.find_zone!(@zone).local(2026, 8, 6, 12, 0, 0) do
      seed_second_journey!(title: "Mine", area_key: "self", battle_title: "My fight")

      other = users(:two)
      allow_extra_climbs!(other)
      other.create_notification_preference!(time_zone: @zone) unless other.notification_preference
      other.notification_preference.update!(time_zone: @zone)
      other_focused = seed_climb!(other, area_key: "career", title: "Other user", today_mission: "Other fight")
      LifeAreas::Select.call(user: other, keys: [ "self" ])
      area = other.life_areas.v2_selected.find_by!(key: "self")
      foreign = Journeys::Create.call(
        user: other,
        life_area: area,
        title: "Foreign peak",
        ideal_scene: "Ideal",
        current_reality: "Present",
        next_win: "Next",
        closer_percent: 20
      )
      goal = other.strategy_goals.create!(
        user: other, life_area: area, life_journey: foreign,
        horizon: "goal", title: "Foreign peak", position: 0
      )
      plan = goal.children.create!(
        user: other, life_area: area, life_journey: foreign,
        horizon: "plan", title: "Plan", position: 0
      )
      project = plan.children.create!(
        user: other, life_area: area, life_journey: foreign,
        horizon: "project", title: "Camp", position: 0
      )
      project.children.create!(
        user: other, life_area: area, life_journey: foreign,
        horizon: "day", title: "Foreign fight", scheduled_on: @today, position: 0
      )

      result = Today::OtherMountainsOpenCounts.call(
        user: @user,
        focused_journey: @focused,
        date: @today
      )

      refute_includes result.journeys.map(&:journey_id), foreign.id
      refute_includes result.journeys.map(&:journey_id), other_focused.id
      result.journeys.each do |entry|
        assert_equal @user.id, @user.life_journeys.find(entry.journey_id).user_id
      end
    end
  end

  test "query count stays flat for one vs eight other journeys" do
    travel_to Time.find_zone!(@zone).local(2026, 8, 6, 12, 0, 0) do
      seed_second_journey!(title: "Climb 1", area_key: "self", battle_title: "Battle 1")

      Battles::WinsOnLocalDate.time_zone_for(@user)
      Battles::WinsOnLocalDate.local_today_for(@user)
      one_queries = count_sql_queries do
        Today::OtherMountainsOpenCounts.call(
          user: @user,
          focused_journey: @focused,
          date: @today
        )
      end

      area_keys = %w[purpose money learning relationships family home community creativity]
      area_keys.each_with_index do |area_key, i|
        n = i + 2
        seed_second_journey!(title: "Climb #{n}", area_key: area_key, battle_title: "Battle #{n}")
      end

      Battles::WinsOnLocalDate.time_zone_for(@user)
      Battles::WinsOnLocalDate.local_today_for(@user)
      eight_queries = count_sql_queries do
        Today::OtherMountainsOpenCounts.call(
          user: @user,
          focused_journey: @focused,
          date: @today
        )
      end

      assert_operator one_queries, :<=, 4
      assert_equal one_queries, eight_queries,
                   "expected flat queries (1-journey=#{one_queries}, 8-journey=#{eight_queries})"
    end
  end

  test "counts uncascaded one-shot StrategyGoals without a DailyTodo" do
    travel_to Time.find_zone!(@zone).local(2026, 8, 6, 12, 0, 0) do
      other = seed_second_journey!(title: "Uncascaded", area_key: "self", battle_title: "No todo yet")
      battle = @user.strategy_goals.find_by!(horizon: "day", title: "No todo yet", life_journey_id: other.id)
      assert_nil @user.daily_todos.for_day(@today).find_by(strategy_goal_id: battle.id)

      result = Today::OtherMountainsOpenCounts.call(
        user: @user,
        focused_journey: @focused,
        date: @today
      )

      entry = result.journeys.find { |e| e.journey_id == other.id }
      assert_equal 1, entry.open_count
      assert_equal "Uncascaded", entry.title
      refute entry.custom_photo?
    end
  end

  private

  def seed_second_journey!(title:, area_key:, battle_title:)
    LifeAreas::Select.call(user: @user, keys: [ area_key ])
    area = @user.life_areas.v2_selected.find_by!(key: area_key)
    journey = Journeys::Create.call(
      user: @user,
      life_area: area,
      title: title,
      ideal_scene: "Ideal #{title}",
      current_reality: "Present #{title}",
      next_win: "Next #{title}",
      closer_percent: 20
    )
    goal = @user.strategy_goals.create!(
      user: @user,
      life_area: area,
      life_journey: journey,
      horizon: "goal",
      title: title,
      position: 0
    )
    plan = goal.children.create!(
      user: @user, life_area: area, life_journey: journey,
      horizon: "plan", title: "Plan #{title}", position: 0
    )
    project = plan.children.create!(
      user: @user, life_area: area, life_journey: journey,
      horizon: "project", title: "Camp #{title}", position: 0
    )
    project.children.create!(
      user: @user, life_area: area, life_journey: journey,
      horizon: "day", title: battle_title, scheduled_on: @today, position: 0
    )
    journey
  end

  def count_sql_queries
    queries = 0
    callback = lambda do |_name, _start, _finish, _id, payload|
      next if payload[:cached]
      next if payload[:name] == "SCHEMA" || payload[:name] == "TRANSACTION"

      queries += 1 if payload[:sql].present?
    end

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      yield
    end
    queries
  end
end
