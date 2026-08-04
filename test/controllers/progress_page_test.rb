# frozen_string_literal: true

require "test_helper"

class ProgressPageTest < ActionDispatch::IntegrationTest
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
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
  end

  test "journey page renders mountain points and activity" do
    get life_points_path
    assert_response :success
    assert_match(/Journey/i, response.body)
    assert_match(/How far have you come/i, response.body)
    assert_match(/Action Points/i, response.body)
    assert_match(/Planning points/i, response.body)
    assert_match(/Mountain Summary/i, response.body)
    assert_match(/See activity details/i, response.body)
    assert_match(/Activity/i, response.body)
    assert_match(/7 Days/i, response.body)
    assert_match(/Weekly activity/i, response.body)
    assert_match(/Achievements/i, response.body)
    assert_match(/lp-dash-nav/i, response.body)
    assert_select ".lp-dash-nav__link.is-active", text: /Journey/i
    assert_no_match(/Climb progress/i, response.body)
    assert_select ".lp-progress-donut__center span", text: /Action Points|AP/i
  end

  test "journey mountain percent matches today when strategy goal exists" do
    goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Become debt-free", position: 0
    )
    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: goal, horizon: "plan", title: "Become Job Ready", position: 0
    )
    other_plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: goal, horizon: "plan", title: "Kill debt", position: 1
    )
    project = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project", title: "Portfolio", position: 0
    )
    @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: other_plan, horizon: "project", title: "Budget", position: 0
    )
    project.complete!
    Strategy::SyncCompletion.call(project: project)

    expected = goal.reload.progress_percent.to_i

    get dashboard_path
    assert_response :success
    assert_select ".lp-dash-climb__pct", text: /#{expected}/

    get life_points_path
    assert_response :success
    assert_select ".lp-journey-hero .lp-dash-hero__pct", text: /#{expected}\s*%/
    assert_match(/Become debt-free/i, response.body)
    assert_match(/Plans Completed/i, response.body)
    assert_match(/Current Expedition/i, response.body)
    assert_match(/Become Job Ready|Kill debt/i, response.body)
    assert_no_match(/\b#{@journey.closer_percent.round}%\b/, response.body) if @journey.closer_percent.round != expected
  end

  test "period query updates selected chip" do
    get life_points_path(period: "30d")
    assert_response :success
    assert_match(/period=30d.*is-active|is-active.*30 Days/i, response.body)
  end

  test "nav labels are mountain today journey you" do
    get life_points_path
    assert_select ".lp-dash-nav__link", text: /Today/i
    assert_select ".lp-dash-nav__link", text: /Mountain/i
    assert_select ".lp-dash-nav__link", text: /Habits/i
    assert_select ".lp-dash-nav__link", text: /Journey/i
    assert_select ".lp-dash-nav__link", text: /You/i
    assert_select ".lp-dash-nav__link", text: /\A\s*Progress\s*\z/, count: 0
  end
end
