# frozen_string_literal: true

require "test_helper"

class TodayProjectColourTest < ActionDispatch::IntegrationTest
  include ClimbTestHelper

  setup do
    @user = users(:one)
    sign_in_as @user
    @journey = seed_climb!(@user, today_mission: "Ship auth")
    dismiss_onboarding_missions!(@user)
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

  test "tagged project paints stripe and camp pill with project name" do
    get dashboard_path
    assert_response :success

    assert_select ".lp-today-v2-row[data-todo-id=?]", @tagged_todo.id.to_s do
      assert_select ".lp-today-v2-row__title", text: "Ship auth"
      assert_select ".lp-today-v2-row__camp", text: /Auth/
      assert_select ".lp-today-v2-row__stripe", count: 1
    end
  end

  test "untagged project shows camp pill without a colour stripe class" do
    get dashboard_path
    assert_response :success

    assert_select ".lp-today-v2-row[data-todo-id=?]", @untagged_todo.id.to_s do
      assert_select ".lp-today-v2-row__title", text: "Write docs"
      assert_select ".lp-today-v2-row__camp", text: /Untagged work/
    end
    assert_select ".lp-dash-tcard.has-color[data-todo-id=?]", @untagged_todo.id.to_s, count: 0
  end

  test "holding-camp battle is an ordinary row with no camp stripe" do
    get dashboard_path
    assert_response :success

    holding_title = I18n.t("strategy.holding.project_title")
    holding_plan_title = I18n.t("strategy.holding.plan_title")
    refute_includes response.body, holding_title
    refute_includes response.body, holding_plan_title

    assert_select ".lp-today-v2-row[data-todo-id=?]", @holding_todo.id.to_s do
      assert_select ".lp-today-v2-row__title", text: "Call the dentist"
      assert_select ".lp-today-v2-row__stripe", count: 0
    end
  end
end
