# frozen_string_literal: true

require "test_helper"

class HoldingInvisibilityTest < ActionDispatch::IntegrationTest
  include StrategyHelper

  setup do
    @user = users(:one)
    sign_in_as @user
    @journey = seed_climb!(@user, today_mission: "Ship auth")
    @holding = Strategy::HoldingProject.ensure!(user: @user, journey: @journey)
    @holding_plan = @holding.parent
    @holding.children.create!(
      user: @user,
      life_area: @journey.life_area,
      life_journey: @journey,
      horizon: "day",
      title: "Call the dentist",
      scheduled_on: Date.current,
      position: 0
    )
    Strategy::CascadeToDaily.call(user: @user, life_area: @journey.life_area)
  end

  test "holding title and DOM ids are absent from Mountain and Today" do
    plan_title = @holding_plan.title
    camp_title = @holding.title
    assert_equal I18n.t("strategy.holding.plan_title"), plan_title
    assert_equal I18n.t("strategy.holding.project_title"), camp_title

    get life_journey_path(@journey)
    assert_response :success
    refute_holding_leaked(response.body, plan_title, camp_title)

    get dashboard_path
    assert_response :success
    refute_holding_leaked(response.body, plan_title, camp_title)
    assert_match(/Call the dentist/, response.body)
  end

  test "Trail and project counts omit holding" do
    plan = @user.strategy_goals.for_kind("goal").roots.first.children.for_kind("plan").not_holding.ordered.first
    trail = Strategy::Trail.for(plan: plan)
    refute trail.nodes.any? { |node| node.record.holding? }

    helper = Class.new { include StrategyHelper; include ActionView::Helpers::TranslationHelper }.new
    assert_equal 1, helper.strategy_projects_count(plan)
  end

  private

  def refute_holding_leaked(body, plan_title, camp_title)
    refute_includes body, plan_title
    refute_includes body, camp_title
    refute_includes body, "camp-edit-#{@holding.id}"
    refute_includes body, "checkpoint-edit-#{@holding.id}"
    refute_includes body, "camp-delete-#{@holding.id}"
    refute_includes body, "strategy_goals/#{@holding.id}"
    refute_includes body, "strategy_goals/#{@holding_plan.id}"
    refute_includes body, "focus_id=#{@holding.id}"
    refute_includes body, "plan_id=#{@holding_plan.id}"
  end
end
