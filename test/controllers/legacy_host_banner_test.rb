# frozen_string_literal: true

require "test_helper"

class LegacyHostBannerTest < ActionDispatch::IntegrationTest
  include ClimbTestHelper

  setup do
    @user = users(:one)
    @user.update!(character: "fox", support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ])
    sign_in_as @user
    seed_climb!(@user, today_mission: "Ship auth")
  end

  test "banner on Render hostname with hidden until JS" do
    host! "lifepoints.onrender.com"
    get dashboard_path
    assert_response :success
    assert_select "#lp-legacy-host-banner[hidden]", count: 1
    assert_select "#lp-legacy-host-banner[data-controller=?]", "legacy-host-banner"
    assert_select "a.lp-legacy-host-banner__cta[href=?]", "https://lifeclimb.app/dashboard"
    assert_select ".lp-legacy-host-banner__title", text: /Life Climb has a new home/
  end

  test "no banner on lifeclimb.app" do
    host! "lifeclimb.app"
    get dashboard_path
    assert_select "#lp-legacy-host-banner", count: 0
  end

  test "no banner on www.lifeclimb.app" do
    host! "www.lifeclimb.app"
    get dashboard_path
    assert_select "#lp-legacy-host-banner", count: 0
  end

  test "no banner on default test host" do
    get dashboard_path
    assert_select "#lp-legacy-host-banner", count: 0
  end

  test "no banner on localhost" do
    host! "localhost"
    get dashboard_path
    assert_select "#lp-legacy-host-banner", count: 0
  end
end
