# frozen_string_literal: true

require "test_helper"

class HabitsBasicEditSheetTest < ActionDispatch::IntegrationTest
  include ClimbTestHelper

  setup do
    enable_habits!
    @user = users(:one)
    sign_in_as @user
    seed_climb!(@user, today_mission: "Edit basics")
    dismiss_onboarding_missions!(@user)
    @journey = @user.reload.primary_focused_journey
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    @plan = @goal.children.find(&:plan?)
    @user.habits.destroy_all
    @habit = @user.habits.create!(
      name: "Pages read",
      unit: "pages",
      points: 5,
      frequency: "daily",
      active: true,
      show_on_home: true,
      stat_type: "growth",
      quantity_checkin: true,
      quick_add_amount: 10,
      life_journey_id: @journey.id
    )
  end

  test "basic edit PATCH updates name unit and quick add for today stream" do
    patch habit_path(@habit),
          params: {
            return_to: "today",
            basic_edit_sheet: "1",
            habit: { name: "Read more", unit: "chapters", quick_add_amount: 5 }
          },
          as: :turbo_stream

    assert_response :success
    @habit.reload
    assert_equal "Read more", @habit.name
    assert_equal "chapters", @habit.unit
    assert_equal 5, @habit.quick_add_amount
    assert_match dom_id(@habit, :today_sheet), response.body
    assert_match "data-tcard-menu-target=\"sheet\"", response.body
  end

  test "basic edit PATCH blank name returns 422" do
    patch habit_path(@habit),
          params: {
            return_to: "today",
            basic_edit_sheet: "1",
            habit: { name: "   ", unit: "pages", quick_add_amount: 10 }
          },
          as: :turbo_stream

    assert_response :unprocessable_entity
    assert_equal "Pages read", @habit.reload.name
  end

  test "basic edit PATCH for mountain refreshes trail-base-sheet" do
    patch habit_path(@habit),
          params: mountain_params.merge(
            habit: { name: "Deep read", unit: "pages", quick_add_amount: 15 }
          ),
          as: :turbo_stream

    assert_response :success
    assert_match "trail-base-sheet", response.body
    assert_match "Deep read", response.body
    assert_equal 15, @habit.reload.quick_add_amount
  end

  test "basic edit destroy from today removes row when others remain" do
    other = @user.habits.create!(
      name: "Water",
      unit: "times",
      points: 5,
      frequency: "daily",
      active: true,
      show_on_home: true,
      stat_type: "growth"
    )

    assert_difference "Habit.count", -1 do
      delete habit_path(@habit),
             params: { return_to: "today" },
             as: :turbo_stream
    end

    assert_response :success
    assert_match(/action="remove"/, response.body)
    assert_match dom_id(@habit, :today), response.body
    assert_match "basics_survived_count", response.body
    assert_no_match %(target="today-anytime-host"), response.body
    assert @user.habits.exists?(other.id)
  end

  test "basic edit destroy last today basic replaces anytime host with add row" do
    assert_difference "Habit.count", -1 do
      delete habit_path(@habit),
             params: { return_to: "today" },
             as: :turbo_stream
    end

    assert_response :success
    assert_match %(target="today-anytime-host"), response.body
    assert_match "lp-dash-anytime__add-basic", response.body
    assert_match I18n.t("dash.anytime.add_basic"), response.body
  end

  test "mountain destroy last basic shows starter and composer" do
    assert_difference "Habit.count", -1 do
      delete habit_path(@habit),
             params: mountain_params,
             as: :turbo_stream
    end

    assert_response :success
    assert_match "trail-base-sheet", response.body
    assert_match "lp-trail-base-sheet__starter", response.body
    assert_match "lp-trail-battles__composer", response.body
    assert_no_match "Pages read", response.body
  end

  private

  def mountain_params
    {
      return_to: "mountain",
      basic_edit_sheet: "1",
      life_journey_id: @journey.id,
      goal_id: @goal.id,
      plan_id: @plan.id
    }
  end
end
