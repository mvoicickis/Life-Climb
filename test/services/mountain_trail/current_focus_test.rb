# frozen_string_literal: true

require "test_helper"

module MountainTrail
  class CurrentFocusTest < ActiveSupport::TestCase
    setup do
      @user = users(:one)
      @user.daily_todos.delete_all
    end

    test "returns camp and battle from first plan spine" do
      journey = seed_mountain_spine!(
        camp_title: "Auth camp",
        battle_title: "Ship login",
        camp_y: 0.75
      )

      result = CurrentFocus.for(user: @user)

      assert_equal journey, result.journey
      assert_equal "Auth camp", result.camp.title
      assert_equal "Ship login", result.battle.title
    end

    test "picks lowest open camp on trail" do
      seed_mountain_spine!(
        camps: [
          { title: "Summit", y: 0.4, battle: "High step" },
          { title: "Base", y: 0.8, battle: "Low step" }
        ]
      )

      result = CurrentFocus.for(user: @user)

      assert_equal "Base", result.camp.title
      assert_equal "Low step", result.battle.title
    end

    test "returns nil camp and battle when spine is missing" do
      result = CurrentFocus.for(user: @user)

      assert_nil result.camp
      assert_nil result.battle
    end

    test "returns nil battle when camp has no open day children" do
      seed_mountain_spine!(battle_title: nil)

      result = CurrentFocus.for(user: @user)

      assert result.camp.present?
      assert_nil result.battle
    end

    private

    def seed_mountain_spine!(camp_title: "Camp", battle_title: "Battle", camp_y: 0.7, camps: nil)
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

      if camps
        camps.each_with_index do |entry, index|
          camp = plan.children.create!(
            user: @user, life_area: area, life_journey: journey,
            horizon: "project", title: entry[:title], position: index,
            trail_x: 0.5, trail_y: entry[:y]
          )
          next if entry[:battle].blank?

          camp.children.create!(
            user: @user, life_area: area, life_journey: journey,
            horizon: "day", title: entry[:battle], scheduled_on: Date.current, position: 0
          )
        end
      else
        camp = plan.children.create!(
          user: @user, life_area: area, life_journey: journey,
          horizon: "project", title: camp_title, position: 0,
          trail_x: 0.5, trail_y: camp_y
        )
        if battle_title.present?
          camp.children.create!(
            user: @user, life_area: area, life_journey: journey,
            horizon: "day", title: battle_title, scheduled_on: Date.current, position: 0
          )
        end
      end

      journey
    end
  end
end
