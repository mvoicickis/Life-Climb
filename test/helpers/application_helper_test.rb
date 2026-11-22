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
    disable_habits!

    refute habits_enabled?
  end

  test "habits_enabled? is true for developer when GameRules is off" do
    disable_habits!
    @user.update_columns(developer: true)

    assert habits_enabled?
  end

  test "habits_enabled? is true for non-developer when GameRules is on" do
    enable_habits!

    assert habits_enabled?
  end

  test "app_version returns APP_VERSION constant" do
    assert_equal APP_VERSION, app_version
    assert app_version.present?
    assert_operator app_version.length, :<=, 7
  end

  test "active_goal_title prefers strategy goal title" do
    journey = LifeJourney.new(title: "Journey title")
    goal = StrategyGoal.new(title: "Everest")

    assert_equal "Everest", active_goal_title(strategy_goal: goal, journey: journey)
  end

  test "active_goal_title falls back to journey title" do
    journey = LifeJourney.new(title: "Journey title")

    assert_equal "Journey title", active_goal_title(strategy_goal: nil, journey: journey)
  end

  test "active_goal_title falls back to dash command when no goal or journey" do
    assert_equal I18n.t("dash.active_goal_fallback"), active_goal_title
  end

  test "hero_animal_image_path prefers You avatar then companion then bird" do
    @user.update!(avatar_key: nil, character: nil)
    assert_equal "avatars/bird.webp", hero_animal_image_path(@user)

    @user.update!(character: "fox")
    assert_equal "characters/fox.png", hero_animal_image_path(@user)

    @user.update!(avatar_key: "bird")
    assert_equal "avatars/bird.webp", hero_animal_image_path(@user)

    assert_equal "avatars/bird.webp", hero_animal_image_path(nil)
  end
end
