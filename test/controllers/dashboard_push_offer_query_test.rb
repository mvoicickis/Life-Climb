# frozen_string_literal: true

require "test_helper"

class DashboardPushOfferQueryTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Ship LifePoints",
      ideal_scene: "Live",
      current_reality: "Building",
      next_win: "Launch",
      today_mission: "Code",
      closer_percent: 20
    )
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    @user.update!(
      push_offer_dismiss_count: 0,
      push_offer_dismissed_at: nil,
      push_offer_permission_denied_at: nil,
      push_offer_last_shown_on: nil
    )
    @user.push_subscriptions.delete_all
    @zone = Battles::WinsOnLocalDate.time_zone_for(@user)
  end

  def count_dashboard_queries
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
      get dashboard_path
      assert_response :success
    end
    queries
  end

  def seed_battle_wins(count:)
    @user.strategy_goals.battles.update_all(completed_at: nil)
    goal = @user.strategy_goals.find_by!(horizon: "goal")
    plan = @user.strategy_goals.find_by!(horizon: "plan", parent_id: goal.id)
    project = @user.strategy_goals.find_by!(horizon: "project", parent_id: plan.id)
    leaf = practice_leaf_for!(project)
    count.times do |i|
      battle = if i.zero?
        @user.strategy_goals.battles.first ||
          @user.strategy_goals.create!(
            life_area: @area,
            life_journey: @journey,
            parent: leaf,
            horizon: "day",
            title: "Win #{i}",
            scheduled_on: Date.current - 1.day,
            position: 0
          )
      else
        @user.strategy_goals.create!(
          life_area: @area,
          life_journey: @journey,
          parent: leaf,
          horizon: "day",
          title: "Win #{i}",
          scheduled_on: Date.current - (i + 1).days,
          position: i
        )
      end
      battle.update!(
        completed_at: Time.find_zone!(@zone).local(2026, 1, 10 + i, 9, 0, 0)
      )
    end
  end

  test "ever won check uses same query count for one win vs many wins" do
    seed_battle_wins(count: 1)
    single = count_dashboard_queries

    seed_battle_wins(count: 12)
    many = count_dashboard_queries

    assert_equal single, many, "expected exists?-style ever won lookup, got single=#{single} many=#{many}"
  end
end
