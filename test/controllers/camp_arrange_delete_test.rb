# frozen_string_literal: true

require "test_helper"

class CampArrangeDeleteTest < ActionDispatch::IntegrationTest
  def registration_params(email)
    {
      user: {
        name: "Alex",
        email_address: email,
        password: "password12345",
        password_confirmation: "password12345"
      }
    }
  end

  def finish_onboarding!(email:, goal:, camps:)
    post registration_url, params: registration_params(email)
    follow_redirect!
    patch v2_onboarding_url(step: "goal"), params: { onboarding: { goal: goal } }
    patch v2_onboarding_url(step: "camps"), params: { onboarding: { camp_titles: camps } }
    follow_redirect!
    user = User.find_by!(email_address: email)
    user.primary_focused_journey.clear_first_camp_reveal!
    user
  end

  def assert_stream_replaces_arrange_overlay(body)
    assert_match(/action="replace"[^>]*target="trail-arrange-camps"/, body)
  end

  def assert_stream_removes_arrange_overlay(body)
    assert_match(/action="remove"[^>]*target="trail-arrange-camps"/, body)
  end

  def mountain_path_for(user)
    journey = user.primary_focused_journey
    plan = user.strategy_goals.for_kind("plan").not_holding.first
    goal = plan.root_goal
    life_journey_path(journey, goal_id: goal.id, plan_id: plan.id)
  end

  test "delete camp from arrange moves won battle to holding without lowering points" do
    user = finish_onboarding!(
      email: "camp-delete@example.com",
      goal: "Ship the app",
      camps: [ "Alpha camp", "Beta camp", "Gamma camp" ]
    )
    journey = user.primary_focused_journey
    plan = user.strategy_goals.for_kind("plan").not_holding.first
    camps = plan.children.for_kind("project").not_holding.order(:position).to_a
    camp_to_delete = camps.second

    holding = Strategy::HoldingProject.ensure!(user: user, journey: journey)
    battle = camp_to_delete.children.for_kind("day").create!(
      user: user,
      life_area: journey.life_area,
      life_journey: journey,
      horizon: "day",
      title: "Win on beta",
      scheduled_on: Date.current,
      position: 0
    )
    Strategy::CascadeToDaily.call(user: user, life_area: journey.life_area)
    todo = user.daily_todos.find_by!(strategy_goal_id: battle.id, scheduled_on: Date.current)
    post complete_daily_todo_path(todo)
    follow_redirect!

    battle.reload
    assert battle.completed?

    points_before = user.reload.total_points
    sp_before = user.strategy_points
    streak_days = user.climb_streak_days
    streak_on = user.climb_streak_on

    delete strategy_goal_path(camp_to_delete, arrange_open: 1), as: :turbo_stream
    assert_response :success

    battle.reload
    assert_equal holding.id, battle.parent_id
    assert_not StrategyGoal.exists?(camp_to_delete.id)

    user.reload
    assert_equal points_before, user.total_points
    assert_equal sp_before, user.strategy_points
    assert_equal streak_days, user.climb_streak_days
    assert_equal streak_on, user.climb_streak_on

    assert_stream_replaces_arrange_overlay(response.body)
    assert_match(/aria-hidden="false"/, response.body)
  end

  test "deleting down to one camp removes arrange overlay from stream" do
    user = finish_onboarding!(
      email: "camp-last@example.com",
      goal: "Two camps",
      camps: [ "Keep me", "Gone" ]
    )
    plan = user.strategy_goals.for_kind("plan").not_holding.first
    camp = plan.children.for_kind("project").not_holding.order(:position).second

    delete strategy_goal_path(camp, arrange_open: 1), as: :turbo_stream
    assert_response :success
    assert_stream_removes_arrange_overlay(response.body)

    get mountain_path_for(user)
    assert_response :success
    assert_select "#trail-arrange-camps", count: 0
    assert_select ".lp-trail__goal-menu button[data-action*='openArrangeCamps']", count: 0
  end

  test "three camps keep arrange overlay open after delete" do
    user = finish_onboarding!(
      email: "camp-three@example.com",
      goal: "Three peaks",
      camps: [ "One", "Two", "Three" ]
    )
    plan = user.strategy_goals.for_kind("plan").not_holding.first
    camp = plan.children.for_kind("project").not_holding.order(:position).second

    delete strategy_goal_path(camp, arrange_open: 1), as: :turbo_stream
    assert_response :success
    assert_stream_replaces_arrange_overlay(response.body)
    assert_match(/aria-hidden="false"/, response.body)
  end

  test "quantified camp delete has no undo stash or toast" do
    user = finish_onboarding!(
      email: "camp-q@example.com",
      goal: "Quant goal",
      camps: [ "Q camp", "Other" ]
    )
    journey = user.primary_focused_journey
    plan = user.strategy_goals.for_kind("plan").not_holding.first
    camp = plan.children.for_kind("project").not_holding.order(:position).first
    camp.update!(
      quantity_kind: "up",
      target_amount: 10,
      unit: "pages",
      current_amount: 5
    )
    camp.strategy_quantity_logs.create!(
      user: user,
      amount: 5,
      unit: "pages",
      logged_on: Date.current
    )

    delete strategy_goal_path(camp, arrange_open: 1), as: :turbo_stream
    assert_response :success
    assert_no_match "trail-toast-host", response.body

    post strategy_goal_restores_path
    assert_redirected_to %r{/}
    assert_equal I18n.t("strategy.rpg.trail.undo_expired"), flash[:alert]
  end

  test "holding camp delete returns unprocessable entity for turbo stream" do
    user = finish_onboarding!(
      email: "camp-hold@example.com",
      goal: "Hold",
      camps: [ "A", "B" ]
    )
    journey = user.primary_focused_journey
    holding = Strategy::HoldingProject.ensure!(user: user, journey: journey)

    delete strategy_goal_path(holding), as: :turbo_stream
    assert_response :unprocessable_entity
    assert StrategyGoal.exists?(holding.id)
  end

  test "arrange overlay shows trash on active camps not holding" do
    user = finish_onboarding!(
      email: "camp-trash@example.com",
      goal: "Trash UI",
      camps: [ "A", "B" ]
    )
    journey = user.primary_focused_journey
    holding = Strategy::HoldingProject.ensure!(user: user, journey: journey)

    get mountain_path_for(user)
    assert_response :success
    assert_select "#trail-arrange-camps .lp-trail-arrange-row__trash", minimum: 2
    assert_select "#trail-arrange-camps [data-camp-id=?] .lp-trail-arrange-row__trash", holding.id.to_s, count: 0
  end
end
