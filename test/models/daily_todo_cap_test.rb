# frozen_string_literal: true

require "test_helper"

class DailyTodoCapTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @day = Date.current
  end

  test "within_daily_cap allows create when only completed todos fill the day" do
    GameRules::MAX_DAILY_TODOS.times do |i|
      @user.daily_todos.create!(
        title: "Done #{i}",
        aspect_key: "self",
        scheduled_on: @day,
        position: i,
        lp_reward: GameRules::BATTLE_TODO_LP,
        completed_at: Time.current
      )
    end

    todo = @user.daily_todos.new(
      title: "Fresh open",
      aspect_key: "self",
      scheduled_on: @day,
      position: GameRules::MAX_DAILY_TODOS,
      lp_reward: GameRules::BATTLE_TODO_LP
    )

    assert todo.valid?
    assert todo.save
  end

  test "within_daily_cap rejects create when open todos reach max" do
    GameRules::MAX_DAILY_TODOS.times do |i|
      @user.daily_todos.create!(
        title: "Open #{i}",
        aspect_key: "self",
        scheduled_on: @day,
        position: i,
        lp_reward: GameRules::BATTLE_TODO_LP
      )
    end

    todo = @user.daily_todos.new(
      title: "One too many",
      aspect_key: "self",
      scheduled_on: @day,
      position: GameRules::MAX_DAILY_TODOS,
      lp_reward: GameRules::BATTLE_TODO_LP
    )

    assert_not todo.valid?
    assert_includes todo.errors[:base], I18n.t("dash.battle_day_full", max: GameRules::MAX_DAILY_TODOS)
  end
end
