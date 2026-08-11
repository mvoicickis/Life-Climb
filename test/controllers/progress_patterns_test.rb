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

  test "patterns panel is absent when history is thin" do
    get life_points_path
    assert_response :success
    assert_select ".lp-patterns", count: 0
  end

  test "patterns panel renders after trends when findings exist" do
    10.times do |i|
      day = Date.current - i
      @user.daily_todos.create!(
        title: "Pattern A #{i}",
        aspect_key: "money",
        scheduled_on: day,
        completed_at: day.to_time.change(hour: 12),
        position: 0
      )
      @user.daily_todos.create!(
        title: "Pattern B #{i}",
        aspect_key: "money",
        scheduled_on: day,
        completed_at: (i < 5 ? day.to_time.change(hour: 13) : nil),
        position: 1
      )
    end

    get life_points_path
    assert_response :success
    assert_select ".lp-patterns"
    assert_select ".lp-patterns__observation"
    assert_select ".lp-patterns__cta"
    assert_match(/Your patterns/, response.body)
    # Outside the collapsed details block
    body = response.body
    patterns_idx = body.index('class="lp-patterns"')
    details_idx = body.index('class="lp-journey-details"')
    assert patterns_idx
    assert details_idx
    assert_operator patterns_idx, :<, details_idx
  end
end
