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
  end
end
