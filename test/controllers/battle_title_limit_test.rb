# frozen_string_literal: true

require "test_helper"

class BattleTitleLimitTrailTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    allow_extra_climbs!(@user)
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Ship LifePoints",
      ideal_scene: "App live",
      current_reality: "Building",
      next_win: "Launch",
      today_mission: "Write tests",
      closer_percent: 20
    )
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    post strategy_goals_path, params: {
      life_area_id: @area.id, life_journey_id: @journey.id,
      horizon: "goal", title: "Trail summit"
    }
    @goal = @user.strategy_goals.for_kind("goal").last
    post strategy_goals_path, params: {
      life_area_id: @area.id, life_journey_id: @journey.id,
      parent_id: @goal.id, horizon: "plan", title: "Main path"
    }
    @plan = @user.strategy_goals.for_kind("plan").last
    post strategy_goals_path, params: {
      life_area_id: @area.id, life_journey_id: @journey.id,
      parent_id: @plan.id, horizon: "project", title: "Base camp",
      color_key: "teal", trail_x: 0.48, trail_y: 0.72
    }
    @project = @user.strategy_goals.for_kind("project").last
  end

  test "trail camp battle composer uses TITLE_MAX and title limit UI" do
    get life_journey_path(@journey, focus_id: @project.id)

    assert_response :success
    assert_select "#trail-battles-#{@project.id} input[name=title][maxlength=?]", StrategyGoal::TITLE_MAX.to_s
    assert_select "#trail-battles-#{@project.id} .lp-title-limit[data-controller*='title-limit']"
    assert_select "#trail-battles-#{@project.id} .lp-title-limit__count[role=status]"
  end
end

class BattleTitleLimitCommitmentGapTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(character: "fox", climb_streak_days: 0, climb_streak_on: nil)
    sign_in_as @user
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Find a job",
      ideal_scene: "Hired",
      current_reality: "Searching",
      today_mission: "Plan the path",
      closer_percent: 10,
      route_mission: true
    )
    @journey = @user.reload.primary_focused_journey
    enable_habits!
    @journey.update!(
      commitment_key: "medium",
      commitment_name: "Medium",
      commitment_habit_count: 3,
      commitment_battle_count: 3
    )
    seed_today_habits!(3)
    3.times do |n|
      @user.daily_todos.create!(
        title: "Timed #{n}", scheduled_on: Date.current, aspect_key: "career",
        start_time: "09:00", end_time: "10:00", position: 40 + n
      )
    end
  end

  test "commitment gap battle quick add uses TITLE_MAX and title limit UI" do
    get dashboard_path

    assert_response :success
    assert_select "#commitment-gap-panel[data-next-action-key=commitment_gap]"
    assert_select "#commitment-gap-panel input[name=title][maxlength=?]", StrategyGoal::TITLE_MAX.to_s
    assert_select "#commitment-gap-panel .lp-title-limit[data-controller*='title-limit']"
  end

  private

  def seed_today_habits!(count)
    have = @user.habits.active.on_home.count
    (have + 1).upto(count) do |n|
      @user.habits.create!(
        name: "Habit #{n}", unit: "times", points: 5, frequency: "daily",
        active: true, show_on_home: true, quantity_checkin: false
      )
    end
  end
end

class BattleTitleLimitOnboardingTest < ActionDispatch::IntegrationTest
  test "v2 onboarding battles step uses TITLE_MAX and title limit UI" do
    email = "battle-limit-#{SecureRandom.hex(4)}@example.com"
    post registration_url, params: {
      user: {
        name: "Alex",
        email_address: email,
        password: "password12345",
        password_confirmation: "password12345"
      }
    }
    follow_redirect!
    patch v2_onboarding_url(step: "character"), params: { user: { character: "fox" } }
    follow_redirect!
    patch v2_onboarding_url(step: "goal"), params: { onboarding: { goal: "Become a Ruby Developer" } }
    follow_redirect!
    patch v2_onboarding_url(step: "camp"), params: { onboarding: { camp: "Get certified" } }
    follow_redirect!

    assert_response :success
    assert_select "input[name='onboarding[battle_titles][]'][maxlength=?]", StrategyGoal::TITLE_MAX.to_s
    assert_select ".lp-adventure__battle-field[data-controller*='title-limit']"
  end
end
