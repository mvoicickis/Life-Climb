# frozen_string_literal: true

require "test_helper"

class ProgressPeriodFrameTest < ActionDispatch::IntegrationTest
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

  test "full page keeps period activity outside details and heatmap inside" do
    get life_points_path(period: "30d")
    assert_response :success

    assert_select "#progress_activity"
    assert_select "#progress_activity .lp-progress-filters"
    assert_select "#progress_activity .lp-progress-kpis"
    assert_select "#progress_activity .lp-progress-growth"
    assert_select "#progress_activity .lp-progress-categories"
    assert_select "#progress_activity .lp-progress-insights"
    assert_select "#progress_activity .lp-progress-filters__chip.is-active", text: /30 Days/i

    assert_select ".lp-journey-details .lp-progress-filters", count: 0
    assert_select ".lp-journey-details .lp-progress-heatmap"
    assert_match(/See weekly activity/, response.body)
    assert_no_match(/Charts and filters/i, response.body)
  end

  test "outer wrapper keeps achievements controller without chart values" do
    get life_points_path
    assert_response :success

    assert_select ".lp-progress[data-controller='progress-achievements']"
    assert_select ".lp-progress[data-progress-charts-growth-value]", count: 0
    assert_select ".lp-progress[data-progress-charts-categories-value]", count: 0
  end

  test "frame and full page share the same period-dependent regions" do
    get life_points_path(period: "90d")
    assert_response :success
    full = response.body

    get life_points_path(period: "90d"), headers: { "Turbo-Frame" => "progress_activity" }
    assert_response :success
    frame = response.body

    assert_includes full, 'id="progress_activity"'
    assert_includes frame, 'id="progress_activity"'

    %w[
      lp-progress-filters
      lp-progress-kpis
      lp-progress-growth
      lp-progress-categories
      lp-progress-insights
    ].each do |region|
      assert_includes full, region, "full page missing #{region}"
      assert_includes frame, region, "frame response missing #{region}"
    end

    assert_includes frame, "3 Months"
    assert_select "a.lp-progress-filters__chip.is-active", text: /3 Months/i
  end

  test "frame response includes progress-charts data attributes for Chart.js" do
    get life_points_path(period: "7d"), headers: { "Turbo-Frame" => "progress_activity" }
    assert_response :success

    assert_select "turbo-frame#progress_activity[data-controller='progress-charts']"
    assert_select "turbo-frame#progress_activity[data-progress-charts-growth-value]"
    assert_select "turbo-frame#progress_activity[data-progress-charts-categories-value]"
    assert_match(/data-turbo-frame="progress_activity"/, response.body)
    assert_match(/data-turbo-action="advance"/, response.body)
  end

  test "chip CSS uses the tap target token" do
    css = Rails.root.join("app/assets/tailwind/application.css").read
    chip_block = css[/\.lp-progress-filters__chip\s*\{[^}]+\}/m]
    assert_not_nil chip_block
    assert_match(/min-height:\s*var\(--lp-tap,\s*2\.75rem\)/, chip_block)
    assert_match(/display:\s*inline-flex/, chip_block)
    assert_match(/align-items:\s*center/, chip_block)
  end
end
