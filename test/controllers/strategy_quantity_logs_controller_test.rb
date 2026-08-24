# frozen_string_literal: true

require "test_helper"

class StrategyQuantityLogsControllerTest < ActionDispatch::IntegrationTest
  include ClimbTestHelper

  setup do
    @user = users(:one)
    sign_in_as @user
    seed_climb!(@user, area_key: "career", title: "Ship LifePoints", today_mission: "Write tests")
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    @goal = @user.strategy_goals.for_area(@area.id).for_kind("goal").roots.first
    @plan = @goal.children.find(&:plan?)
    @project = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Read pages", position: 0,
      target_amount: 100, unit: "pages", current_amount: 0
    )
    @battle = @project.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Read 10 pages", position: 0,
      scheduled_on: Date.current
    )
  end

  test "logs quantity and wins the mountain battle" do
    assert_difference -> { StrategyQuantityLog.count }, 1 do
      post strategy_quantity_logs_path, params: {
        project_id: @project.id,
        battle_id: @battle.id,
        amount: "10",
        life_journey_id: @journey.id
      }
    end

    assert_redirected_to life_journey_path(
      @journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @project.id
    )
    @project.reload
    @battle.reload
    assert_equal BigDecimal("10"), @project.current_amount
    assert @battle.completed?
  end

  private

  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: "password12345" }
  end
end
