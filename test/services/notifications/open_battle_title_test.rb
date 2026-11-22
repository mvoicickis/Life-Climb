# frozen_string_literal: true

require "test_helper"

module Notifications
  class OpenBattleTitleTest < ActiveSupport::TestCase
    setup do
      @user = users(:one)
      @user.daily_todos.delete_all
      @user.life_journeys.delete_all
      @user.strategy_goals.delete_all
    end

    test "prefers linked incomplete todo" do
      seed_climb!(@user, today_mission: "Camp battle")
      date = Date.new(2026, 8, 6)
      battle = @user.strategy_goals.where(horizon: "day").order(:id).last
      @user.daily_todos.delete_all
      @user.daily_todos.create!(
        title: "First todo",
        aspect_key: "career",
        scheduled_on: date,
        position: 0,
        lp_reward: 10,
        strategy_goal_id: battle.id,
        tag: "strategy"
      )

      assert_equal "First todo", OpenBattleTitle.for(user: @user, on: date)
      open = OpenBattle.for(user: @user, on: date)
      assert_equal @user.daily_todos.find_by!(title: "First todo").id, open.daily_todo_id
    end

    test "falls back to due strategy goal when no todos" do
      travel_to Time.zone.local(2026, 8, 6, 12, 0, 0) do
        seed_climb!(@user, today_mission: "Read for ten minutes")
        date = Date.current
        @user.daily_todos.delete_all
        battle = @user.strategy_goals.where(horizon: "day").order(:id).last
        battle.update!(scheduled_on: date)

        assert_equal "Read for ten minutes", OpenBattleTitle.for(user: @user, on: date)
      end
    end

    test "skips strategy goal already won on date" do
      travel_to Time.zone.local(2026, 8, 6, 12, 0, 0) do
        seed_climb!(@user, today_mission: "Done battle")
        date = Date.current
        @user.daily_todos.delete_all
        battle = @user.strategy_goals.where(horizon: "day").order(:id).last
        battle.update!(scheduled_on: date, completed_at: Time.zone.local(2026, 8, 6, 7, 0, 0))

        assert_nil OpenBattleTitle.for(user: @user, on: date)
      end
    end

    test "does not create records" do
      travel_to Time.zone.local(2026, 8, 6, 12, 0, 0) do
        seed_climb!(@user, today_mission: "Quiet step")
        date = Date.current
        @user.daily_todos.delete_all
        todo_count = DailyTodo.count

        OpenBattleTitle.for(user: @user, on: date)

        assert_equal todo_count, DailyTodo.count
      end
    end

    test "ignores open todos from a non-focused journey" do
      first = seed_climb!(@user, area_key: "career", title: "Focused", today_mission: "Focused fight")
      second_area = @user.life_areas.v2_selected.find_by!(key: "career")
      second = Journeys::Create.call(
        user: @user,
        life_area: second_area,
        title: "Other goal",
        ideal_scene: "Ideal",
        current_reality: "Now",
        next_win: "Next",
        closer_percent: 20
      )
      goal = @user.strategy_goals.create!(
        user: @user, life_area: second_area, life_journey: second,
        horizon: "goal", title: "Other goal", position: 0
      )
      plan = goal.children.create!(
        user: @user, life_area: second_area, life_journey: second,
        horizon: "plan", title: "Plan", position: 0
      )
      camp = plan.children.create!(
        user: @user, life_area: second_area, life_journey: second,
        horizon: "project", title: "Camp", position: 0
      )
      other_battle = camp.children.create!(
        user: @user, life_area: second_area, life_journey: second,
        horizon: "day", title: "Other fight", scheduled_on: Date.current, position: 0
      )
      Strategy::CascadeToDaily.call(user: @user, life_area: second_area, from: Date.current, to: Date.current)
      assert_equal first.id, @user.primary_focused_journey.id

      date = Date.current
      assert @user.daily_todos.for_day(date).exists?(strategy_goal_id: other_battle.id)
      title = OpenBattleTitle.for(user: @user, on: date)
      assert_equal "Focused fight", title
    end
  end
end
