# frozen_string_literal: true

require "test_helper"

class HabitDestroyTurboCacheTest < ActionDispatch::IntegrationTest
  include ClimbTestHelper

  setup do
    @user = users(:one)
    sign_in_as @user
    seed_climb!(@user, today_mission: "Ship auth")
    @user.habits.destroy_all
    @habit = @user.habits.create!(
      name: "Temp stretch", unit: "times", points: 5, frequency: "daily",
      active: true, show_on_home: true, stat_type: "growth"
    )
  end

  test "destroy removes habit and asks the client to clear Turbo page cache" do
    assert_difference -> { @user.habits.count }, -1 do
      delete habit_path(@habit)
    end
    assert_redirected_to habits_path
    follow_redirect!
    assert_response :success
    assert_select "[data-controller='turbo-cache'][data-turbo-cache-clear-value='true']"
    assert_select ".lp-habits__name", text: "Temp stretch", count: 0

    get dashboard_path
    assert_response :success
    assert_select ".lp-dash-section.is-habits .lp-dash-battle__name", text: "Temp stretch", count: 0
  end
end
