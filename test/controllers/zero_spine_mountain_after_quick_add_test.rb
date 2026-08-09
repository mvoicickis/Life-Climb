# frozen_string_literal: true

require "test_helper"

class ZeroSpineMountainAfterQuickAddTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(character: "fox")
    sign_in_as @user
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Zero Spine Peak",
      ideal_scene: "Climbing",
      current_reality: "At trailhead",
      today_mission: "Plan the path",
      closer_percent: 10,
      route_mission: true
    )
    @journey = @user.reload.primary_focused_journey
    goal = @user.strategy_goals.for_kind("goal").roots.first
    goal.children.find_each(&:destroy!)
    @user.daily_todos.for_day(Date.current).find_each(&:destroy!)
    travel_to Time.zone.local(Date.current.year, Date.current.month, Date.current.day, 11, 0, 0)
  end

  teardown { travel_back }

  test "after zero-spine quick-add Mountain shows Plan Project nested camp and battle" do
    post dashboard_quick_battles_path,
         params: {
           title: "Outline MVP spine",
           end_time: (Time.current + 90.minutes).strftime("%H:%M")
         },
         as: :turbo_stream
    assert_response :success

    goal = @user.strategy_goals.for_kind("goal").roots.first
    plan = goal.children.for_kind("plan").ordered.first
    project = plan.children.for_kind("project").ordered.first
    todo = @user.daily_todos.for_day(Date.current).order(:id).last
    day = todo.strategy_goal

    assert_equal "Outline MVP spine", plan.title
    assert_equal "Outline MVP spine", project.title
    assert project.path_level_camp?
    assert day.parent.project?
    assert_equal "Outline MVP spine", day.title

    get life_journey_path(@journey)
    assert_response :success
    assert_match(/Outline MVP spine/, response.body)
    # Drill into plan focus — titles must still resolve from DB.
    get life_journey_path(@journey, focus_id: plan.id)
    assert_response :success
    assert_match(/Outline MVP spine/, response.body)
    get life_journey_path(@journey, focus_id: project.id)
    assert_response :success
    assert_match(/Outline MVP spine/, response.body)
  end
end
