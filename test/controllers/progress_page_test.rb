# frozen_string_literal: true

require "test_helper"

class ProgressPageTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    allow_extra_climbs!(@user)
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

  test "stats page renders simplified sections without legacy charts" do
    get life_points_path
    assert_response :success

    assert_select ".lp-stats-hero"
    assert_select ".lp-stats-hero__label", text: /Battles won/i
    assert_select ".lp-stats-block", minimum: 1
    assert_select "turbo-frame#stats_calendar"
    assert_select ".lp-stats-milestones"

    assert_select ".lp-progress__top", count: 0
    assert_select ".stats-hero", count: 0
    assert_select ".lp-journey-trends", count: 0
    assert_select ".lp-progress-changed", count: 0
    assert_select ".lp-patterns", count: 0
    assert_select "#progress_activity", count: 0
    assert_select ".lp-journey-details", count: 0
    assert_select ".lp-feedback-fab", count: 0

    assert_no_match(/Battle strength/i, response.body)
    assert_no_match(/Planning power/i, response.body)
    assert_no_match(/Action Points/i, response.body)
    assert_no_match(/\bAP\b/, response.body)
    assert_no_match(/\bLP\b/, response.body)
    assert_no_match(/What changed/i, response.body)
    assert_no_match(/See weekly activity/i, response.body)
    assert_no_match(/More stats/i, response.body)

    assert_select ".lp-dash-nav__link.is-active", text: /Stats/i
  end

  test "stats hero shows mountain bar and open mountain link" do
    get life_points_path
    assert_response :success
    assert_select ".lp-stats-hero__bar .lp-dash-bar__fill"
    assert_select ".lp-stats-hero__link", text: /Open Mountain/i
  end

  test "stats hero percent matches strategy goal progress" do
    goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Become debt-free", position: 0
    )
    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: goal, horizon: "plan", title: "Become Job Ready", position: 0
    )
    project = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project", title: "Portfolio", position: 0
    )
    project.complete!
    Strategy::SyncCompletion.call(project: project)

    expected = goal.reload.progress_percent.to_i

    get life_points_path
    assert_response :success
    assert_select ".lp-stats-hero__bar .lp-dash-bar__fill[style*='width: #{expected}%']"
  end

  test "camps section omits zero-win camps and ellipsizes long names" do
    goal = @user.strategy_goals.for_area(@area.id).for_kind("goal").roots.first
    goal ||= @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Financial freedom", position: 0
    )
    plan = goal.children.find { |c| c.plan? && !c.holding? } ||
           @user.strategy_goals.create!(
             life_area: @area, life_journey: @journey, parent: goal, horizon: "plan", title: "Path", position: 99
           )
    long_title = "Wake up early before the house is loud and the street starts beeping"
    project = @user.strategy_goals.create!(
      life_area: @area,
      life_journey: @journey,
      parent: plan,
      horizon: "project",
      title: long_title,
      position: 99
    )
    battle = @user.strategy_goals.create!(
      life_area: @area,
      life_journey: @journey,
      parent: project,
      horizon: "day",
      title: "Win once",
      scheduled_on: Date.current,
      position: 0
    )
    battle.update!(completed_at: Time.current)
    empty_project = @user.strategy_goals.create!(
      life_area: @area,
      life_journey: @journey,
      parent: plan,
      horizon: "project",
      title: "Quiet camp",
      position: 100
    )
    empty_project.children.create!(
      user: @user,
      life_area: @area,
      life_journey: @journey,
      horizon: "day",
      title: "Never won",
      scheduled_on: Date.current,
      position: 0
    )

    get life_points_path
    assert_response :success
    assert_select ".lp-stats-row__name", text: long_title
    assert_select ".lp-stats-row", count: 1
    assert_no_match(/Quiet camp/, response.body)
  end

  test "this week section hidden with zero wins" do
    get life_points_path
    assert_response :success
    assert_select "#stats-week-heading", count: 0
  end

  test "nav labels are mountain today you stats" do
    get life_points_path
    assert_select ".lp-dash-nav__link", text: /Today/i
    assert_select ".lp-dash-nav__link", text: /Mountain/i
    assert_select ".lp-dash-nav__link", text: /You/i
    assert_select ".lp-dash-nav__link", text: /Stats/i
    assert_select ".lp-dash-nav__link", text: /\A\s*Progress\s*\z/, count: 0
  end

  test "journey stats section is not rendered" do
    get life_points_path
    assert_response :success
    assert_select ".lp-journey-stats", count: 0
  end
end
