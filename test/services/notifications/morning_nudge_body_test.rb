# frozen_string_literal: true

require "test_helper"

module Notifications
  class MorningNudgeBodyTest < ActiveSupport::TestCase
    setup do
      @user = users(:one)
      @user.daily_todos.delete_all
    end

    test "personal body names camp and battle with straight quotes" do
      journey = seed_spine!(camp: "Learn guitar", battle: "Practice chords 10 min")

      result = MorningNudgeBody.for(user: @user, locale: :en)

      assert_includes result.body, 'At Learn guitar: "Practice chords 10 min". Open your camp.'
      assert result.body.start_with?("☀️ ")
      assert_includes result.url, "/life_journeys/#{journey.id}"
      assert_includes result.url, "focus_id="
      assert_includes result.url, "open_camp=1"
      assert result.battle_id.present?
    end

    test "truncates long camp and battle titles" do
      seed_spine!(
        camp: "A" * 40,
        battle: "B" * 50
      )

      result = MorningNudgeBody.for(user: @user, locale: :en)

      assert_includes result.body, "#{"A" * 24}..."
      assert_includes result.body, "#{"B" * 36}..."
      assert result.body.length <= Notifications::MorningNudgeBody::BODY_LIMIT
    end

    test "falls back to generic phrase bank and dashboard" do
      pool = (0..5).map { |i| I18n.t("notifications.morning_nudge.#{i}", locale: :en) }

      result = MorningNudgeBody.for(user: @user, locale: :en)

      assert_equal "/dashboard", result.url
      assert_nil result.battle_id
      assert result.body.start_with?("☀️ ")
      assert_includes pool, result.body.delete_prefix("☀️ ")
    end

    private

    def seed_spine!(camp:, battle:)
      Onboarding::Run.call(
        user: @user,
        area_key: "career",
        title: "Ship",
        ideal_scene: "Live",
        current_reality: "Build",
        next_win: "Launch",
        today_mission: "Test",
        closer_percent: 20,
        route_mission: true
      )
      journey = @user.reload.primary_focused_journey
      area = journey.life_area
      goal = @user.strategy_goals.for_kind("goal").roots.first
      plan = goal.children.create!(
        user: @user, life_area: area, life_journey: journey,
        horizon: "plan", title: "Path", position: 0
      )
      project = plan.children.create!(
        user: @user, life_area: area, life_journey: journey,
        horizon: "project", title: camp, position: 0,
        trail_x: 0.5, trail_y: 0.75
      )
      project.children.create!(
        user: @user, life_area: area, life_journey: journey,
        horizon: "day", title: battle, scheduled_on: Date.current, position: 0
      )
      journey
    end
  end
end
