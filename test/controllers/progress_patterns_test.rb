# frozen_string_literal: true

require "test_helper"

class ProgressPatternsTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    Onboarding::Run.call(
      user: @user,
      area_key: "money",
      title: "Financial freedom",
      ideal_scene: "Calm savings",
      current_reality: "Budgeting",
      next_win: "Emergency fund",
      today_mission: "Track spending",
      closer_percent: 25
    )
    @user.reload
  end

  test "patterns panel is never shown on stats" do
    get life_points_path
    assert_response :success
    assert_select ".lp-patterns", count: 0
  end

  test "patterns panel stays hidden when history is rich" do
    10.times do |i|
      day = Date.current - i
      @user.daily_todos.create!(
        title: "Pattern A #{i}",
        aspect_key: "money",
        scheduled_on: day,
        completed_at: day.to_time.change(hour: 12),
        position: 0
      )
    end

    get life_points_path
    assert_response :success
    assert_select ".lp-patterns", count: 0
    assert_no_match(/Your patterns/, response.body)
  end
end
