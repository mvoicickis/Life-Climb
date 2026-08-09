# frozen_string_literal: true

require "test_helper"

module Battles
  class QuickAddTodayTest < ActiveSupport::TestCase
    setup do
      @user = users(:one)
      seed_climb!(@user, area_key: "career", today_mission: "Ship auth")
    end

    test "creates day battle and today todo from category example" do
      career_examples = Array(I18n.t("strategy.first_climb.examples.career.action"))

      result = nil
      assert_difference -> { @user.daily_todos.for_day.count }, 1 do
        result = QuickAddToday.call(user: @user, category: "career")
      end

      assert_includes career_examples, result.title
      assert_equal "career", result.category
      assert result.todo.persisted?
      refute result.todo.completed?
      assert_equal Date.current, result.battle.scheduled_on
      assert result.battle.day?
    end

    test "different categories produce different example pools" do
      self_examples = Array(I18n.t("strategy.first_climb.examples.self.action"))
      career_examples = Array(I18n.t("strategy.first_climb.examples.career.action"))
      refute_equal self_examples.sort, career_examples.sort

      self_result = QuickAddToday.call(user: @user, category: "self", title: self_examples.first)
      career_result = QuickAddToday.call(user: @user, category: "career", title: career_examples.first)

      assert_equal self_examples.first, self_result.title
      assert_equal career_examples.first, career_result.title
      refute_equal self_result.title, career_result.title
    end

    test "auto-creates Plan and path Project from battle title when spine is missing" do
      @user = users(:two)
      Onboarding::Run.call(
        user: @user,
        area_key: "career",
        title: "Empty mountain",
        ideal_scene: "Done",
        current_reality: "Start",
        today_mission: "Anything",
        closer_percent: 10,
        route_mission: true
      )
      journey = @user.reload.primary_focused_journey
      goal = @user.strategy_goals.for_kind("goal").roots.first
      assert goal.present?
      assert_equal 0, goal.children.for_kind("plan").count

      result = QuickAddToday.call(user: @user, category: "career", title: "Write the first test")

      plan = goal.reload.children.for_kind("plan").ordered.first
      project = plan.children.for_kind("project").ordered.first
      assert_equal "Write the first test", plan.title
      assert_equal "Write the first test", project.title
      assert project.path_level_camp?
      assert result.battle.parent.nested_leaf_camp?
      assert_equal I18n.t("strategy.first_climb.nested_camp_title"), result.battle.parent.title
      assert result.todo.persisted?
      assert_equal journey.life_area_id, result.battle.life_area_id
    end

    test "attaches under last-touched open path Project not first by position" do
      journey = @user.primary_focused_journey
      goal = @user.strategy_goals.for_kind("goal").roots.first
      plan = goal.children.for_kind("plan").ordered.first
      first = plan.children.for_kind("project").ordered.first
      second = plan.children.create!(
        user: @user,
        life_area: journey.life_area,
        life_journey: journey,
        horizon: "project",
        title: "Later camp",
        position: first.position.to_i + 10
      )
      leaf = PracticeParent.call(user: @user, project: second)
      recent = leaf.children.create!(
        user: @user,
        life_area: journey.life_area,
        life_journey: journey,
        horizon: "day",
        title: "Touch later camp",
        scheduled_on: Date.yesterday,
        position: 0
      )
      recent.update_columns(updated_at: Time.current + 1.minute)

      result = QuickAddToday.call(user: @user, category: "career", title: "Next fight under later")

      path = result.battle.parent
      path = path.parent while path && !path.path_level_camp?
      assert_equal second.id, path.id
      refute_equal first.id, path.id
    end
  end
end
