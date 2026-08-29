# frozen_string_literal: true

require "test_helper"

class StrategyGoalQuantityUiTest < ActionDispatch::IntegrationTest
  include ClimbTestHelper

  setup do
    @user = users(:one)
    sign_in_as @user
    seed_climb!(@user, area_key: "career", title: "Ship LifePoints", today_mission: "Write tests")
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    @goal = @user.strategy_goals.for_area(@area.id).for_kind("goal").roots.first
    @plan = @goal.children.find(&:plan?) || @goal.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: "MVP path", position: 0
    )
  end

  test "creating a quantified path-level project stores target and unit" do
    assert_difference -> { @user.strategy_goals.for_kind("project").count }, 1 do
      post strategy_goals_path, params: {
        life_area_id: @area.id,
        life_journey_id: @journey.id,
        parent_id: @plan.id,
        horizon: "project",
        title: "Read Atomic Habits",
        track_quantity: "1",
        target_amount: "700",
        unit: "pages"
      }
    end

    project = @user.strategy_goals.for_kind("project").find_by!(title: "Read Atomic Habits")
    assert project.quantified?
    assert_equal BigDecimal("700"), project.target_amount
    assert_equal "pages", project.unit
    assert_equal BigDecimal("0"), project.current_amount
  end

  test "creating a project without track toggle stays binary" do
    post strategy_goals_path, params: {
      life_area_id: @area.id,
      life_journey_id: @journey.id,
      parent_id: @plan.id,
      horizon: "project",
      title: "Plain camp"
    }

    project = @user.strategy_goals.for_kind("project").find_by!(title: "Plain camp")
    assert_not project.quantified?
    assert_nil project.target_amount
    assert_nil project.unit
  end

  test "section card shows quantity progress for quantified projects" do
    project = @plan.children.select(&:project?).sort_by { |p| [ p.position.to_i, p.id ] }
                 .find { |p| !p.completed? }
    project ||= @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Debt payoff", position: 99
    )
    project.update!(title: "Debt payoff", target_amount: 15_000, unit: "€", current_amount: 500)
    practice_leaf_for!(project)

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: project.id)
    assert_response :success
    assert_select "#trail-camp-#{project.id} .lp-trail-camp__tent"
    assert_select "#trail-camp-#{project.id}[aria-label=?]", "Debt payoff"
    assert_select "#trail-camp-#{project.id} .lp-trail-camp__meta", count: 0
    assert_select "#trail-camp-#{project.id} .lp-trail__camp-bar", count: 0
  end

  test "non-quantified project shows a count-up battle line, never Active or a bar" do
    project = @plan.children.select(&:project?).sort_by { |p| [ p.position.to_i, p.id ] }
                 .find { |p| !p.completed? }
    assert project.present?
    project.update!(target_amount: nil, unit: nil, current_amount: 0)

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: project.id)
    assert_response :success
    assert_select "#trail-camp-#{project.id} .lp-trail-camp__tent"
    assert_select "#trail-camp-#{project.id} .lp-trail-camp__meta", count: 0
    assert_select "#trail-camp-#{project.id} .lp-trail__camp-bar", count: 0
  end

  test "editing quantified project updates target and unit without resetting current_amount" do
    project = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Outreach", position: 0,
      target_amount: 200, unit: "emails", current_amount: 42
    )

    patch strategy_goal_path(project), params: {
      title: "Outreach",
      track_quantity: "1",
      target_amount: "250",
      unit: "emails sent"
    }

    project.reload
    assert_equal BigDecimal("250"), project.target_amount
    assert_equal "emails sent", project.unit
    assert_equal BigDecimal("42"), project.current_amount
  end

  test "new project form includes quantity track toggle" do
    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id)
    assert_response :success
    # Quantity fields remain on the visually hidden list-fallback add form.
    assert_select ".lp-trail__list-fallback #rpg-add-section-#{@plan.id} input[name='track_quantity']"
    assert_select ".lp-trail__list-fallback #rpg-add-section-#{@plan.id} input[name='target_amount']"
    assert_select ".lp-trail__list-fallback #rpg-add-section-#{@plan.id} input[name='unit']"
  end

  test "path-focus Place first checkpoint form includes quantity track toggle" do
    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id)
    assert_response :success
    assert_select ".lp-trail-plant"
    assert_select ".lp-trail-plant input[name='title']"
    assert_select ".lp-trail-plant textarea[name='description']"
    assert_select ".lp-trail__plant-colors input[name='color_key']", minimum: 1
    assert_select ".lp-trail-plant__wheel", count: 0
    assert css_select(".lp-trail-plant input[name='quantity_kind']").none? { |input| input["checked"] }
    assert_select ".lp-trail-plant input[name='track_quantity']"
    assert_select ".lp-trail-plant input[name='target_amount']"
    assert_select ".lp-trail-plant input[name='unit']"
    assert_select "#rpg-add-checkpoint", count: 0
  end

  test "path-focus Place first checkpoint accepts and saves quantity fields" do
    assert_difference -> { @user.strategy_goals.for_kind("project").count }, 1 do
      post strategy_goals_path, params: {
        life_area_id: @area.id,
        life_journey_id: @journey.id,
        parent_id: @plan.id,
        horizon: "project",
        title: "First checkpoint pages",
        track_quantity: "1",
        target_amount: "120",
        unit: "pages"
      }
    end

    project = @user.strategy_goals.for_kind("project").find_by!(title: "First checkpoint pages")
    assert project.quantified?
    assert_equal BigDecimal("120"), project.target_amount
    assert_equal "pages", project.unit
    assert_equal BigDecimal("0"), project.current_amount
  end

  test "path-focus Place first checkpoint accepts optional description" do
    assert_difference -> { @user.strategy_goals.for_kind("project").count }, 1 do
      post strategy_goals_path, params: {
        life_area_id: @area.id,
        life_journey_id: @journey.id,
        parent_id: @plan.id,
        horizon: "project",
        title: "Strength camp",
        description: "Build a daily push-up habit"
      }
    end

    project = @user.strategy_goals.for_kind("project").find_by!(title: "Strength camp")
    assert_equal "Build a daily push-up habit", project.description
  end

  private

  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: "password12345" }
  end
end
