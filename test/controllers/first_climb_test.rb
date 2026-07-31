# frozen_string_literal: true

require "test_helper"

class FirstClimbTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Become a licensed plumber",
      ideal_scene: "Own my van and clients",
      current_reality: "Working a day job",
      next_win: "Pass first exam section",
      today_mission: "Study",
      closer_percent: 5,
      route_mission: true
    )
    @user.update!(support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ])
    @journey = @user.reload.primary_focused_journey
    @goal = @user.strategy_goals.for_kind("goal").roots.first
  end

  test "new climber sees first-climb coach instead of crowded mountain chrome" do
    get life_journey_path(@journey)
    assert_response :success
    assert_select "#first-climb-coach"
    assert_select ".lp-first-climb__cta[value=?]", "Start my climb"
    assert_select "#strategy-camp-notebook", count: 0
    assert_select ".lp-world-hud__chip.is-sp", count: 0
  end

  test "first climb scaffolds plan project battle and opens today fight" do
    assert_difference -> { @user.strategy_goals.for_kind("day").count }, +1 do
      post first_climbs_path, params: {
        life_journey_id: @journey.id,
        goal_id: @goal.id,
        plan_title: "Get certified",
        today_action: "Study chapter 1 for 20 minutes"
      }
    end

    assert_redirected_to dashboard_path
    follow_redirect!
    assert_response :success
    assert_select ".lp-dash-human-win__body", text: /Study chapter 1/i
    assert_select ".lp-dash-route.is-first-climb", count: 0
    assert @user.daily_todos.for_day(Date.current).exists?(title: "Study chapter 1 for 20 minutes")
    assert Strategy::HierarchyReady.call(user: @user, journey: @journey)
    assert_equal @goal.id, @user.strategy_goals.for_kind("plan").find_by!(title: "Get certified").parent_id
  end

  test "first climb scaffolds under the active destination not the first root" do
    first = @goal
    second = @user.strategy_goals.create!(
      life_area: @journey.life_area, life_journey: @journey,
      horizon: "goal", title: "Health Summit", position: 1
    )

    post first_climbs_path, params: {
      life_journey_id: @journey.id,
      goal_id: second.id,
      plan_title: "Run path",
      today_action: "Jog 20 minutes"
    }
    assert_redirected_to dashboard_path

    plan = @user.strategy_goals.for_kind("plan").find_by!(title: "Run path")
    assert_equal second.id, plan.parent_id
    assert_equal 0, first.children.for_kind("plan").count
    assert_equal 1, second.children.for_kind("plan").count

    get life_journey_path(@journey, goal_id: second.id)
    assert_response :success
    assert_select "#first-climb-coach", count: 0
    assert_select ".lp-rpg-path", text: /Run path/

    get life_journey_path(@journey, goal_id: first.id)
    assert_response :success
    assert_select "#first-climb-coach"
    assert_select ".lp-first-climb__goal", text: /Become a licensed plumber/i
  end

  test "initialized destination never replays first-climb when switching back" do
    post first_climbs_path, params: {
      life_journey_id: @journey.id,
      goal_id: @goal.id,
      plan_title: "Get certified",
      today_action: "Study chapter 1"
    }
    other = @user.strategy_goals.create!(
      life_area: @journey.life_area, life_journey: @journey,
      horizon: "goal", title: "Side quest", position: 1
    )
    other.children.create!(
      user: @user, life_area: @journey.life_area, life_journey: @journey,
      horizon: "plan", title: "Other path", position: 0
    )

    get life_journey_path(@journey, goal_id: other.id)
    assert_select "#first-climb-coach", count: 0
    assert_select ".lp-rpg-path", text: /Other path/

    get life_journey_path(@journey, goal_id: @goal.id)
    assert_select "#first-climb-coach", count: 0
    assert_select ".lp-rpg-path", text: /Get certified/
  end

  test "today dead-end shows first-climb coach when spine empty" do
    get dashboard_path
    assert_response :success
    assert_select "#first-climb-coach"
    assert_select ".lp-first-climb__title", text: /today count/i
    assert_select "#first-climb-coach input[name=goal_id][value=?]", @goal.id.to_s
  end
end
