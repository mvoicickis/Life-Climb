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
    assert_select ".lp-dash-nav__link", text: /Habits/i
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
    assert_no_match(/Create a Project to improve this/i, response.body)

    @habit.update!(state: "attention")
    get habit_path(@habit)
    assert_response :success
    assert_match(/Create a Project to improve this/i, response.body)
    assert_select "form[action=?]", habit_improvement_projects_path(@habit)
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
end
