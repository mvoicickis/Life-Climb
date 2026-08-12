# frozen_string_literal: true

require "test_helper"

class TodayCommitmentUiTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(character: "fox", climb_streak_days: 0, climb_streak_on: nil)
    sign_in_as @user
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Find a job",
      ideal_scene: "Hired",
      current_reality: "Searching",
      today_mission: "Plan the path",
      closer_percent: 10,
      route_mission: true,
      commitment_key: "easy"
    )
    @journey = @user.reload.primary_focused_journey
    travel_to Time.zone.local(Date.current.year, Date.current.month, Date.current.day, 10, 0, 0)
  end

  teardown do
    travel_back
  end

  test "Today shows tier and shield badges, progress strip, and no Win on Today CTA" do
    get dashboard_path
    assert_response :success

    assert_select "[data-commitment-tier]", text: /Easy/i
    assert_select "[data-day-shield]"
    assert_select "[data-commitment-progress]", text: /Habits/i
    assert_select "[data-commitment-progress]", text: /Battles/i
    assert_select "a.lp-cta", text: "Win on Today", count: 0
    assert_no_match(/>\s*Win on Today\s*</, response.body)
  end

  test "quantity Anytime Win stays disabled until amount is filled" do
    goal = @user.strategy_goals.for_kind("goal").roots.first
    plan = goal.children.create!(
      user: @user, life_area: @journey.life_area, life_journey: @journey,
      horizon: "plan", title: "Build", position: 0
    )
    project = plan.children.create!(
      user: @user, life_area: @journey.life_area, life_journey: @journey,
      horizon: "project", title: "Auth", position: 0
    )
    nested = project.children.create!(
      user: @user, life_area: @journey.life_area, life_journey: @journey,
      horizon: "project", title: "Steps", position: 0
    )
    nested.children.create!(
      user: @user, life_area: @journey.life_area, life_journey: @journey,
      horizon: "day", title: "Send emails", scheduled_on: Date.current, position: 0
    )
    Strategy::CascadeToDaily.call(user: @user, life_area: @journey.life_area)

    @user.habits.create!(
      name: "Push-ups", unit: "times", points: 5, frequency: "daily",
      active: true, show_on_home: true, quantity_checkin: true, stat_type: "growth"
    )

    get dashboard_path
    assert_response :success

    assert_select ".lp-dash-tcard__qty[data-controller~='quantity-win']" do
      assert_select "input.lp-dash-tcard__amount[required]"
      assert_select "input[type=submit][disabled]"
    end
  end

  test "level up prompt hidden when next tier ineligible despite streak" do
    habit = @user.habits.create!(
      name: "Water", unit: "glasses", points: 5, frequency: "daily",
      active: true, show_on_home: true, quantity_checkin: false
    )
    habit.completions.create!(user: @user, completed_on: Date.current, points_awarded: habit.points)
    @user.daily_todos.create!(
      title: "Timed fight", scheduled_on: Date.current, aspect_key: "career",
      completed_at: Time.current, start_time: "09:00", end_time: "10:00", position: 1
    )
    @journey.update!(
      commitment_key: "easy",
      commitment_name: "Easy",
      commitment_habit_count: 1,
      commitment_battle_count: 1,
      commitment_met_streak_days: 2,
      commitment_met_on: Date.yesterday,
      commitment_level_up_declined_on: nil
    )

    get dashboard_path
    assert_response :success
    assert_equal 3, @journey.reload.commitment_met_streak_days
    assert_select "[data-commitment-level-up]", count: 0
  end

  test "level up accept moves Easy to Medium when eligible and decline suppresses for the day" do
    3.times do |n|
      @user.habits.create!(
        name: "Habit #{n}", unit: "times", points: 5, frequency: "daily",
        active: true, show_on_home: true, quantity_checkin: false
      )
    end
    goal = @user.strategy_goals.for_kind("goal").roots.first
    plan = goal.children.create!(
      user: @user, life_area: @journey.life_area, life_journey: @journey,
      horizon: "plan", title: "More plans", position: 5
    )
    2.times do |n|
      plan.children.create!(
        user: @user, life_area: @journey.life_area, life_journey: @journey,
        horizon: "project", title: "Bare #{n}", position: n
      )
    end
    # Onboarding::Run may not seed camps — ensure capacity via path camps above + any existing.
    while Today::Commitment.camp_capacity(@journey) < 3
      plan.children.create!(
        user: @user, life_area: @journey.life_area, life_journey: @journey,
        horizon: "project", title: "Bare extra #{SecureRandom.hex(2)}",
        position: plan.children.maximum(:position).to_i + 1
      )
    end

    habit = @user.habits.active.on_home.where(quantity_checkin: false).first!
    habit.completions.create!(user: @user, completed_on: Date.current, points_awarded: habit.points)
    @user.daily_todos.create!(
      title: "Timed fight", scheduled_on: Date.current, aspect_key: "career",
      completed_at: Time.current, start_time: "09:00", end_time: "10:00", position: 1
    )
    @journey.update!(
      commitment_key: "easy",
      commitment_name: "Easy",
      commitment_habit_count: 1,
      commitment_battle_count: 1,
      commitment_met_streak_days: 2,
      commitment_met_on: Date.yesterday,
      commitment_level_up_declined_on: nil
    )

    get dashboard_path
    assert_response :success
    assert_equal 3, @journey.reload.commitment_met_streak_days
    assert_select "[data-commitment-level-up]"

    patch decline_today_commitment_path
    assert_redirected_to dashboard_path
    follow_redirect!
    assert_response :success
    assert_select "[data-commitment-level-up]", count: 0

    @journey.reload.update!(commitment_level_up_declined_on: nil)
    get dashboard_path
    assert_response :success
    assert_select "[data-commitment-level-up]"

    patch level_up_today_commitment_path
    assert_redirected_to dashboard_path
    assert_equal "medium", @journey.reload.commitment_key
  end
end
