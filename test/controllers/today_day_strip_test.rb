# frozen_string_literal: true

require "test_helper"

class TodayDayStripTest < ActionDispatch::IntegrationTest
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

    teal = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Teal camp", position: 2, color_key: "teal"
    )
    teal.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Open teal", scheduled_on: Date.current, position: 0
    )
    amber = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Amber camp", position: 3, color_key: "amber"
    )
    amber.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Open amber", scheduled_on: Date.current, position: 0
    )

    @holding = Strategy::HoldingProject.ensure!(user: @user, journey: @journey)
    @holding.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Call the dentist", scheduled_on: Date.current, position: 0
    )
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)

    @tagged_todo = @user.daily_todos.for_day(Date.current).find_by!(title: "Ship auth")
    @untagged_todo = @user.daily_todos.for_day(Date.current).find_by!(title: "Write docs")
    @open_teal = @user.daily_todos.for_day(Date.current).find_by!(title: "Open teal")
    @open_amber = @user.daily_todos.for_day(Date.current).find_by!(title: "Open amber")
    @holding_todo = @user.daily_todos.for_day(Date.current).find_by!(title: "Call the dentist")
  end

  test "strip shows one bar per battle with won colour and open grey" do
    @tagged_todo.update!(completed_at: Time.current)
    @untagged_todo.update!(completed_at: Time.current)

    get dashboard_path
    assert_response :success

    assert_select ".lp-dash-daystrip__bar", count: 5
    assert_select ".lp-dash-daystrip__label", text: "2 of 5 won"
    assert_select ".lp-dash-daystrip__bar.has-color.is-purple[data-todo-id=?]", @tagged_todo.id.to_s
    assert_select ".lp-dash-daystrip__bar.is-won[data-todo-id=?]", @untagged_todo.id.to_s
    assert_select ".lp-dash-daystrip__bar.has-color[data-todo-id=?]", @untagged_todo.id.to_s, count: 0
    assert_select ".lp-dash-daystrip__bar.is-won[data-todo-id=?]", @open_teal.id.to_s, count: 0
    assert_select ".lp-dash-daystrip__bar.has-color[data-todo-id=?]", @open_teal.id.to_s, count: 0
    assert_select ".lp-dash-daystrip__bar.is-won[data-todo-id=?]", @open_amber.id.to_s, count: 0
    assert_select ".lp-dash-daystrip__bar.has-color[data-todo-id=?]", @holding_todo.id.to_s, count: 0
    refute_includes response.body, I18n.t("strategy.holding.project_title")
  end

  test "won-untagged bar is distinct from an open bar" do
    @untagged_todo.update!(completed_at: Time.current)

    get dashboard_path
    assert_response :success

    assert_select ".lp-dash-daystrip__bar.is-won[data-todo-id=?]", @untagged_todo.id.to_s
    assert_select ".lp-dash-daystrip__bar.has-color[data-todo-id=?]", @untagged_todo.id.to_s, count: 0
    assert_select ".lp-dash-daystrip__bar.is-won[data-todo-id=?]", @tagged_todo.id.to_s, count: 0
    assert_select ".lp-dash-daystrip__bar.has-color[data-todo-id=?]", @tagged_todo.id.to_s, count: 0
  end

  test "empty Today hides the strip" do
    @user.daily_todos.for_day(Date.current).destroy_all

    get dashboard_path
    assert_response :success
    assert_select ".lp-dash-daystrip", count: 0
  end
end
