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

  test "after zero-spine quick-add the battle is held invisibly and Mountain stays first-climb" do
    post dashboard_quick_battles_path,
         params: {
           title: "Outline MVP spine",
           end_time: (Time.current + 90.minutes).strftime("%H:%M")
         },
         as: :turbo_stream
    assert_response :success

    goal = @user.strategy_goals.for_kind("goal").roots.first
    todo = @user.daily_todos.for_day(Date.current).order(:id).last
    day = todo.strategy_goal

    assert day.parent.holding?
    assert_equal "Outline MVP spine", day.title
    assert_equal 0, goal.children.for_kind("plan").not_holding.count

    get life_journey_path(@journey)
    assert_response :success
    refute_includes response.body, I18n.t("strategy.holding.plan_title")
    refute_includes response.body, I18n.t("strategy.holding.project_title")
    assert_select ".lp-rpg.is-first-climb"
  end
end
