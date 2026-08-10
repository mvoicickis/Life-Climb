# frozen_string_literal: true

require "test_helper"

class Dashboard::QuickBattlesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(character: "fox")
    sign_in_as @user
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Find a job",
      ideal_scene: "Hired",
      current_reality: "Searching",
      today_mission: "Plan the path",
      closer_percent: 10,
      route_mission: true
    )
    @journey = @user.reload.primary_focused_journey
    @user.habits.active.on_home.update_all(show_on_home: false)
    @journey.update!(
      commitment_key: "medium",
      commitment_name: "Medium",
      commitment_habit_count: 3,
      commitment_battle_count: 3
    )
    # Clear setup_gap habits pillar so quick-battle turbo keeps the commitment_gap panel.
    3.times do |n|
      @user.habits.create!(
        name: "Habit #{n}", unit: "times", points: 5, frequency: "daily",
        active: true, show_on_home: true, quantity_checkin: false
      )
    end
    travel_to Time.zone.local(Date.current.year, Date.current.month, Date.current.day, 10, 0, 0)
  end

  teardown { travel_back }

  test "creates timed battle for current_user only and does not bump battles chip" do
    # Two timed fights already → after create, setup_gap is quiet (3/3) and
    # commitment_gap (camps short) keeps the progress chip at 0/3.
    2.times do |n|
      @user.daily_todos.create!(
        title: "Prior #{n}", scheduled_on: Date.current, aspect_key: "career",
        start_time: "08:00", end_time: "09:00", position: n
      )
    end
    end_time = (Time.current + 1.hour).strftime("%H:%M")

    assert_difference -> { @user.daily_todos.for_day(Date.current).count }, 1 do
      post dashboard_quick_battles_path,
           params: { title: "Outline MVP", end_time: end_time, open_reveal: "battle" },
           as: :turbo_stream
    end
    assert_response :success

    todo = @user.daily_todos.for_day(Date.current).order(:id).last
    assert_equal @user.id, todo.user_id
    assert todo.timed?
    assert_not todo.completed?

    progress = Today::Commitment.progress(user: @user, journey: @journey)
    assert_equal 0, progress.battle_done
    assert_match(/Outline MVP/, response.body)
    assert_match(%r{data-battles-count[^>]*>0/3}, response.body)
  end

  test "zero-spine create turbo-updates surface from plan-route to timeline" do
    goal = @user.strategy_goals.for_kind("goal").roots.first
    assert goal.children.for_kind("plan").none?, "precondition: no plans"
    2.times do |n|
      @user.daily_todos.create!(
        title: "Prior #{n}", scheduled_on: Date.current, aspect_key: "career",
        start_time: "08:00", end_time: "09:00", position: n
      )
    end

    post dashboard_quick_battles_path,
         params: {
           title: "Ship auth",
           end_time: (Time.current + 1.hour).strftime("%H:%M"),
           open_reveal: "battle"
         },
         as: :turbo_stream
    assert_response :success

    assert_match(/today-battle-surface/, response.body)
    assert_match(/Ship auth/, response.body)
    assert_match(/lp-dash-timeline/, response.body)
    assert_no_match(/is-first-climb/, response.body)
    assert_match(/planned, not won yet/, response.body)
  end

  test "rejects blank end_time without creating an untimed battle" do
    before = @user.daily_todos.for_day(Date.current).count

    post dashboard_quick_battles_path,
         params: { title: "No end", end_time: "", open_reveal: "battle" },
         as: :turbo_stream
    assert_response :success
    assert_equal before, @user.daily_todos.for_day(Date.current).count
    assert_match(/Pick when it ends/i, flash[:alert].to_s + response.body)
  end

  test "rejects malformed end_time" do
    before = @user.daily_todos.for_day(Date.current).count

    post dashboard_quick_battles_path,
         params: { title: "Bad end", end_time: "not-a-time", open_reveal: "battle" },
         as: :turbo_stream
    assert_response :success
    assert_equal before, @user.daily_todos.for_day(Date.current).count
  end

  test "another user cannot create battles on this account" do
    other = users(:two)
    sign_in_as other
    Onboarding::Run.call(
      user: other,
      area_key: "career",
      title: "Other mountain",
      ideal_scene: "Done",
      current_reality: "Start",
      today_mission: "Step",
      closer_percent: 10,
      route_mission: true
    )
    other.habits.active.on_home.update_all(show_on_home: false)
    other.primary_focused_journey.update!(
      commitment_key: "medium",
      commitment_name: "Medium",
      commitment_habit_count: 3,
      commitment_battle_count: 3
    )

    assert_no_difference -> { @user.daily_todos.count } do
      post dashboard_quick_battles_path,
           params: {
             title: "Should belong to other",
             end_time: (Time.current + 1.hour).strftime("%H:%M")
           },
           as: :turbo_stream
    end
    todo = other.daily_todos.for_day(Date.current).order(:id).last
    assert_equal other.id, todo.user_id
    assert_not_equal @user.id, todo.user_id
  end
end
