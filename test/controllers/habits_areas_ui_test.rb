# frozen_string_literal: true

require "test_helper"

class HabitsAreasUiTest < ActionDispatch::IntegrationTest
  include ClimbTestHelper

  setup do
    @user = users(:one)
    sign_in_as @user
    seed_climb!(@user, area_key: "money", title: "Financial freedom", today_mission: "Track spending")
    @area = @user.areas.create!(name: "Finance")
    @habit = habits(:one)
  end

  test "index shows areas section and unfiled habits" do
    get habits_path
    assert_response :success
    assert_select "#areas"
    assert_match(/Areas/i, response.body)
    assert_match(/Finance/i, response.body)
    assert_match(/Unfiled Trackers/i, response.body)
    assert_match(@habit.name, response.body)
    assert_select ".lp-dash-nav__link", text: /Habits/i, count: 0
    assert_select ".lp-dash-nav__link", text: /\A\s*Areas\s*\z/, count: 0
  end

  test "form includes area picker" do
    get new_habit_path
    assert_response :success
    assert_select "select[name='habit[area_id]']"
    assert_match(/Unfiled/i, response.body)
  end

  test "show offers improve CTA only when attention" do
    @habit.update!(area: @area, state: "good")
    get habit_path(@habit)
    assert_response :success
    assert_no_match(/Create a Camp to improve this/i, response.body)
    assert_select "form[data-controller='tracker-state']"
    assert_select "form[data-action='change->tracker-state#select']"
    assert_select "[data-tracker-state-target='choice']", count: 3

    @habit.update!(state: "attention")
    get habit_path(@habit)
    assert_response :success
    assert_match(/Create a Camp to improve this/i, response.body)
    assert_select "form[action=?]", habit_improvement_projects_path(@habit)
  end

  test "chip submit saves state without requiring a second control" do
    @habit.update!(area: @area, state: "good")
    patch habit_path(@habit), params: {
      return_to: "show",
      habit: {
        state: "attention",
        state_label_good: @habit.state_label_good,
        state_label_attention: @habit.state_label_attention
      }
    }
    assert_redirected_to habit_path(@habit)
    assert_equal "attention", @habit.reload.state
  end

  test "assigning area from edit keeps habit valid" do
    patch habit_path(@habit), params: {
      habit: {
        name: @habit.name,
        unit: @habit.unit,
        points: @habit.points,
        frequency: @habit.frequency,
        stat_type: @habit.stat_type,
        area_id: @area.id
      }
    }
    assert_redirected_to habits_path
    assert_equal @area.id, @habit.reload.area_id
  end

  test "area move up and down changes order on habits index" do
    first = @user.areas.create!(name: "Alpha", position: 2)
    second = @user.areas.create!(name: "Beta", position: 3)

    patch move_area_path(second), params: { direction: "up" }
    assert_redirected_to habits_path(anchor: "areas")
    assert_equal [ @area.name, "Beta", "Alpha" ], @user.areas.ordered.pluck(:name)

    get habits_path
    assert_response :success
    body = response.body
    assert body.index(">Beta<") < body.index(">Alpha<")
  end

  test "journey visibility toggle hides and shows filed habit" do
    @habit.update!(area: @area, hidden_from_dashboard: false)

    get habits_path
    assert_response :success
    assert_select "button", text: I18n.t("habits.hide_from_journey")

    patch habit_path(@habit), params: { habit: { hidden_from_dashboard: true } }
    assert_redirected_to habits_path
    assert @habit.reload.hidden_from_dashboard?

    get habits_path
    assert_select "button", text: I18n.t("habits.show_on_journey")

    patch habit_path(@habit), params: { habit: { hidden_from_dashboard: false } }
    assert_redirected_to habits_path
    assert_not @habit.reload.hidden_from_dashboard?
  end

  test "journey visibility toggle on unfiled habit" do
    @habit.update!(area_id: nil, hidden_from_dashboard: false)

    get habits_path
    assert_select ".lp-habits__card-actions button", text: I18n.t("habits.hide_from_journey")

    patch habit_path(@habit), params: { habit: { hidden_from_dashboard: true } }
    assert_redirected_to habits_path

    get habits_path
    assert_select ".lp-habits__card-actions button", text: I18n.t("habits.show_on_journey")
  end
end
