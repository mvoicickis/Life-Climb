# frozen_string_literal: true

require "test_helper"

class AppWelcomeTest < ActionDispatch::IntegrationTest
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
    goal = @user.strategy_goals.create!(
      life_area: @area,
      life_journey: @journey,
      horizon: "goal",
      title: "Trail summit",
      position: 0
    )
    plan = @user.strategy_goals.create!(
      life_area: @area,
      life_journey: @journey,
      parent: goal,
      horizon: "plan",
      title: "Main path",
      position: 0
    )
    @user.strategy_goals.create!(
      life_area: @area,
      life_journey: @journey,
      parent: plan,
      horizon: "project",
      title: "Base camp",
      position: 0
    )
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)
  end

  test "today renders welcome overlay with landing hero title" do
    get dashboard_path
    assert_response :success
    assert_select "#lp-app-welcome[hidden][aria-hidden='true']", text: /#{Regexp.escape(I18n.t("landing.hero_title"))}/
    assert_welcome_boot_script!
  end

  test "mountain renders welcome overlay with landing hero title" do
    get life_journey_path(@journey)
    assert_response :success
    assert_select "#lp-app-welcome[hidden][aria-hidden='true']", text: /#{Regexp.escape(I18n.t("landing.hero_title"))}/
    assert_welcome_boot_script!
  end

  test "landing does not render welcome" do
    sign_out
    get root_path
    assert_response :success
    assert_select "#lp-app-welcome", count: 0
    assert_no_welcome_boot_script!
  end

  test "sign in does not render welcome" do
    sign_out
    get new_session_path
    assert_response :success
    assert_select "#lp-app-welcome", count: 0
    assert_no_welcome_boot_script!
  end

  test "v2 onboarding does not render welcome" do
    sign_out
    post registration_url, params: {
      user: {
        name: "Fresh",
        email_address: "welcome-test@example.com",
        password: "password12345",
        password_confirmation: "password12345"
      }
    }
    follow_redirect!
    assert_response :success
    assert_select "#lp-app-welcome", count: 0
    assert_no_welcome_boot_script!
  end

  test "welcome stylesheet includes reduced motion rules" do
    css = Rails.root.join("app/assets/stylesheets/app_welcome.css").read
    assert_match(/prefers-reduced-motion:\s*reduce/, css)
    assert_match(/lp-app-welcome/, css)
  end

  private

  def assert_welcome_boot_script!
    assert_match(/lpAppWelcomeShown/, response.body)
    assert_match(/display-mode:\s*standalone/, response.body)
    assert_match(/lp-app-welcome-pending/, response.body)
    assert_match(/__lpDismissAppWelcome/, response.body)
    assert_match(/DURATION_MS\s*=\s*1500/, response.body)
    assert_match(/setTimeout\(dismiss,\s*DURATION_MS\)/, response.body)
  end

  def assert_no_welcome_boot_script!
    assert_no_match(/lpAppWelcomeShown/, response.body)
    assert_no_match(/lp-app-welcome-pending/, response.body)
  end

  def sign_out
    delete session_path
  end
end
