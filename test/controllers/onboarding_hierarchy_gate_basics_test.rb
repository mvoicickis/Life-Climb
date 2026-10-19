# frozen_string_literal: true

require "test_helper"

class OnboardingHierarchyGateBasicsTest < ActionDispatch::IntegrationTest
  setup { enable_habits! }

  setup do
    @user = User.create!(
      name: "Gate basics",
      email_address: "gate-basics-#{SecureRandom.hex(4)}@example.com",
      password: "password12345",
      password_confirmation: "password12345",
      planning_version: 2,
      onboarding_completed_at: Time.current
    )
    sign_in_as @user
    @result = Onboarding::Bootstrap.call(
      user: @user,
      goal_title: "Climb",
      camp_titles: [ "Camp" ]
    )
    @journey = @result.journey
    @camp = @result.projects.first
    refute Strategy::HierarchyReady.call(user: @user)

    @battle = add_todays_battle!(user: @user, project: @camp, journey: @journey)
    @todo = @user.daily_todos.for_day(Date.current).find_by!(strategy_goal_id: @battle.id)

    @habit = @user.habits.create!(
      name: "Push-Ups",
      unit: "reps",
      points: 5,
      frequency: "daily",
      active: true,
      show_on_home: true,
      stat_type: "growth",
      goal: 25,
      quantity_checkin: true,
      quick_add_amount: 5
    )
    @user.update!(
      push_offer_dismiss_count: 0,
      push_offer_dismissed_at: nil,
      push_offer_permission_denied_at: nil,
      push_offer_show_days: 0
    )
  end

  test "battle completion turbo stream succeeds before hierarchy ready" do
    post complete_daily_todo_path(@todo), as: :turbo_stream

    assert_response :ok
    assert @todo.reload.completed?
  end

  test "daily log turbo stream succeeds before hierarchy ready" do
    post daily_logs_path(habit_id: @habit.id),
         params: {
           mode: "set",
           return_to: "today",
           daily_log: { amount: 12 }
         },
         as: :turbo_stream

    assert_response :ok
    assert_equal 12, @habit.daily_logs.find_by!(logged_on: Date.current).amount
  end

  test "push offer dismiss succeeds before hierarchy ready" do
    delete push_offer_path

    assert_response :no_content
    assert @user.reload.push_offer_dismissed_at.present?
  end
end
