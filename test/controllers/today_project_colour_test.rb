# frozen_string_literal: true

require "test_helper"

class TodayProjectColourTest < ActionDispatch::IntegrationTest
  include ClimbTestHelper

  setup do
    @user = users(:one)
    sign_in_as @user
    @journey = seed_climb!(@user, today_mission: "Ship auth")
    @area = @journey.life_area
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    @plan = @goal.children.find { |c| c.plan? && !c.holding? }
    @tagged = @plan.children.find { |c| c.project? && !c.holding? }
    @tagged.update!(color_key: "purple")

    @untagged = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Untagged work", position: 1
    )
    @untagged.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Write docs", scheduled_on: Date.current, position: 0
    )

    @holding = Strategy::HoldingProject.ensure!(user: @user, journey: @journey)
    @holding.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Call the dentist", scheduled_on: Date.current, position: 0
    )
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)

    @tagged_todo = @user.daily_todos.for_day(Date.current).find_by!(title: "Ship auth")
    @untagged_todo = @user.daily_todos.for_day(Date.current).find_by!(title: "Write docs")
    @holding_todo = @user.daily_todos.for_day(Date.current).find_by!(title: "Call the dentist")
  end

  test "tagged project paints colour class, rail, name, and dot" do
    get dashboard_path
    assert_response :success

    assert_select ".lp-dash-tcard.has-color.is-purple[data-todo-id=?]", @tagged_todo.id.to_s do
      assert_select ".lp-dash-tcard__title", text: "Ship auth"
      assert_select ".lp-dash-tcard__project", text: /Auth/
      assert_select ".lp-dash-tcard__project-dot", count: 1
    end
  end

  test "untagged project shows name and grey dot without a colour class" do
    get dashboard_path
    assert_response :success

    assert_select ".lp-dash-tcard[data-todo-id=?]", @untagged_todo.id.to_s do
      assert_select ".lp-dash-tcard__title", text: "Write docs"
      assert_select ".lp-dash-tcard__project", text: /Untagged work/
      assert_select ".lp-dash-tcard__project-dot", count: 1
    end
    assert_select ".lp-dash-tcard.has-color[data-todo-id=?]", @untagged_todo.id.to_s, count: 0
    assert_select ".lp-dash-tcard.is-purple[data-todo-id=?]", @untagged_todo.id.to_s, count: 0
    assert_select ".lp-dash-tcard.is-teal[data-todo-id=?]", @untagged_todo.id.to_s, count: 0
    assert_select ".lp-dash-tcard.is-coral[data-todo-id=?]", @untagged_todo.id.to_s, count: 0
    assert_select ".lp-dash-tcard.is-amber[data-todo-id=?]", @untagged_todo.id.to_s, count: 0
    assert_select ".lp-dash-tcard.is-blue[data-todo-id=?]", @untagged_todo.id.to_s, count: 0
    assert_select ".lp-dash-tcard.is-green[data-todo-id=?]", @untagged_todo.id.to_s, count: 0
    assert_select ".lp-dash-tcard.is-pink[data-todo-id=?]", @untagged_todo.id.to_s, count: 0
    assert_select ".lp-dash-tcard.is-gray[data-todo-id=?]", @untagged_todo.id.to_s, count: 0
  end

  test "holding-camp battle is an ordinary row with no project node" do
    get dashboard_path
    assert_response :success

    holding_title = I18n.t("strategy.holding.project_title")
    holding_plan_title = I18n.t("strategy.holding.plan_title")
    refute_includes response.body, holding_title
    refute_includes response.body, holding_plan_title

    assert_select ".lp-dash-tcard[data-todo-id=?]", @holding_todo.id.to_s do
      assert_select ".lp-dash-tcard__title", text: "Call the dentist"
      assert_select ".lp-dash-tcard__project", count: 0
      assert_select ".lp-dash-tcard__project-dot", count: 0
    end
    assert_select ".lp-dash-tcard.has-color[data-todo-id=?]", @holding_todo.id.to_s, count: 0
  end
end
