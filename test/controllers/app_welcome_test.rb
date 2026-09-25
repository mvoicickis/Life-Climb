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
    assert_welcome_icon_splash_layout!
    assert_welcome_boot_script!
    assert_welcome_early_paint!
  end

  test "mountain renders welcome overlay with landing hero title" do
    get life_journey_path(@journey)
    assert_response :success
    assert_welcome_icon_splash_layout!
    assert_welcome_boot_script!
    assert_welcome_early_paint!
  end

  test "manifest keeps root start_url for onboarding handoff" do
    get pwa_manifest_path(format: :json)
    assert_response :success
    manifest = JSON.parse(response.body)
    assert_equal "/", manifest["start_url"]
    assert_equal "/", manifest["scope"]
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

  test "welcome stylesheet includes reduced motion rules and readable headline timing" do
    css = Rails.root.join("app/assets/stylesheets/app_welcome.css").read
    critical = Rails.root.join("app/views/shared/_app_welcome_critical.html.erb").read
    assert_match(/prefers-reduced-motion:\s*reduce/, css)
    assert_match(/lp-app-welcome/, css)
    assert_match(/lp-app-welcome-skip-exit/, css)
    assert_match(/--lp-app-welcome-icon:\s*200px/, css)
    assert_match(/\.lp-app-welcome__headline[\s\S]*position:\s*absolute/, css)
    assert_welcome_headline_timing!(css)
    assert_welcome_headline_timing!(critical)
    assert_equal welcome_duration_token(css), welcome_duration_token(critical)
  end

  private

  def assert_welcome_icon_splash_layout!
    assert_select "#lp-app-welcome .lp-app-welcome__stage > .lp-app-welcome__icon img[src='/icon.png?v=8'][width='200'][height='200']"
    assert_select "#lp-app-welcome .lp-app-welcome__stage > .lp-app-welcome__headline",
      text: I18n.t("landing.hero_title")
    assert_select "#lp-app-welcome .lp-app-welcome__stack", count: 0
  end

  def assert_welcome_boot_script!
    boot_script = welcome_boot_script_html
    assert boot_script.present?, "expected welcome boot script in response"
    assert_match(/lpAppWelcomeShown/, boot_script)
    assert_match(/display-mode:\s*standalone/, boot_script)
    assert_match(/lp-app-welcome-pending/, boot_script)
    assert_match(/__lpDismissAppWelcome/, boot_script)
    assert_match(/__lpSkipAppWelcome/, boot_script)
    assert_match(/__lpStartAppWelcomeTimer/, boot_script)
    assert_match(/setTimeout\(dismiss,\s*DURATION_MS\)/, boot_script)
    assert_match(/DURATION_MS = reduced \? 200 :/, boot_script)
    assert_no_match(/DOMContentLoaded/, boot_script)
  end

  def assert_welcome_early_paint!
    assert_select "body > #lp-app-welcome", count: 1
    assert_select "head style", minimum: 1
    assert_match(/__lpStartAppWelcomeTimer/, response.body)
  end

  def welcome_boot_script_html
    doc = Nokogiri::HTML(response.body)
    doc.css("script").map(&:text).find { |js| js.include?("lpAppWelcomeShown") }
  end

  def assert_welcome_headline_timing!(source)
    block = source[/@keyframes lp-app-welcome-headline[\s\S]*?^\}/m]
    assert block, "expected lp-app-welcome-headline keyframes"
    assert_match(/40%\s*\{[\s\S]*opacity:\s*1/, block)
    assert_match(/85%\s*\{[\s\S]*opacity:\s*1/, block)
  end

  def welcome_duration_token(source)
    source[/(--lp-app-welcome-duration:\s*[^;]+)/, 1]
  end

  def assert_no_welcome_boot_script!
    assert_no_match(/lpAppWelcomeShown/, response.body)
    assert_no_match(/lp-app-welcome-pending/, response.body)
  end

  def sign_out
    delete session_path
  end
end
