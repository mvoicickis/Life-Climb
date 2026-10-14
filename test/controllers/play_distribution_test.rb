# frozen_string_literal: true

require "test_helper"

class PlayDistributionTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(
      install_offer_dismiss_count: 0,
      install_offer_dismissed_at: nil,
      install_offer_installed_at: nil
    )
  end

  test "distribution=play sets httponly cookie" do
    get root_path(distribution: "play")

    assert_response :success
    cookie = response.cookies["lp_distribution"]
    assert_equal "play", cookie
    set_cookie = response.headers["Set-Cookie"].to_s
    assert_includes set_cookie, "lp_distribution=play"
    assert_includes set_cookie.downcase, "httponly"
  end

  test "play cookie hides premium install and blocks monetization routes" do
    sign_in_as @user
    cookies[:lp_distribution] = "play"

    get settings_path
    assert_response :success
    assert_select "a[href=?]", pricing_path, count: 0
    assert_select "#you-row-install-offer", count: 0

    get pricing_path
    assert_redirected_to dashboard_path

    get support_path
    assert_redirected_to dashboard_path

    post billing_checkout_path, params: { interval: "monthly" }, as: :json
    assert_response :not_found

    post billing_portal_path, as: :json
    assert_response :not_found
  end

  test "without play cookie monetization surfaces stay available" do
    sign_in_as @user

    get settings_path
    assert_response :success
    assert_select "a[href=?]", pricing_path

    get pricing_path
    assert_response :success

    get support_path
    assert_response :success
  end

  test "android-app referer sets play cookie and hides monetization" do
    sign_in_as @user

    get settings_path, headers: { "HTTP_REFERER" => "android-app://app.lifeclimb/" }
    assert_response :success
    assert_equal "play", response.cookies["lp_distribution"]
    assert_select "a[href=?]", pricing_path, count: 0

    post billing_checkout_path, params: { interval: "monthly" }, as: :json
    assert_response :not_found
  end

  test "android-app referer without trailing slash sets play cookie" do
    get root_path, headers: { "HTTP_REFERER" => "android-app://app.lifeclimb" }
    assert_response :success
    assert_equal "play", response.cookies["lp_distribution"]
  end

  test "similar package name in referer does not set play cookie" do
    sign_in_as @user

    get settings_path, headers: { "HTTP_REFERER" => "android-app://app.lifeclimbfake/" }
    assert_response :success
    assert_nil response.cookies["lp_distribution"]
    assert_select "a[href=?]", pricing_path
  end

  test "non android-app referer does not set play cookie" do
    sign_in_as @user

    get settings_path, headers: { "HTTP_REFERER" => "https://google.com/" }
    assert_response :success
    assert_nil response.cookies["lp_distribution"]
    assert_select "a[href=?]", pricing_path
  end

  test "no referer leaves web monetization unchanged" do
    sign_in_as @user

    get settings_path
    assert_response :success
    assert_nil response.cookies["lp_distribution"]
    assert_select "a[href=?]", pricing_path
  end
end
