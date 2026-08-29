# frozen_string_literal: true

require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  include ApplicationHelper

  def current_user
    @user
  end

  setup do
    @user = users(:one)
    @user.update_columns(developer: false)
  end

  test "habits_enabled? is false for non-developer when GameRules is off" do
    refute habits_enabled?
  end

  test "habits_enabled? is true for developer when GameRules is off" do
    @user.update_columns(developer: true)

    assert habits_enabled?
  end

  test "habits_enabled? is true for non-developer when GameRules is on" do
    enable_habits!

    assert habits_enabled?
  end

  test "habits_on_today_v2? is false for non-developer even when GameRules is on" do
    enable_habits!

    refute habits_on_today_v2?
  end

  test "habits_on_today_v2? is true for developer" do
    @user.update_columns(developer: true)

    assert habits_on_today_v2?
  end
end
