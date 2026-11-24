# frozen_string_literal: true

require "test_helper"

class BetaSignupsControllerTest < ActionDispatch::IntegrationTest
  ANDROID_UA = "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36"

  setup do
    BetaSignup.delete_all
  end

  test "create saves one row with source_path and device" do
    assert_difference "BetaSignup.count", 1 do
      post beta_signups_path,
           params: {
             beta_signup: {
               email: "android@example.com",
               source_path: "/blog/my-post"
             }
           },
           headers: { "User-Agent" => ANDROID_UA },
           as: :turbo_stream
    end

    assert_response :success
    signup = BetaSignup.find_by!(email: "android@example.com")

    assert_equal "/blog/my-post", signup.source_path
    assert_equal "android", signup.device
    assert_includes response.body, I18n.t("beta_card.success")
  end

  test "duplicate email responds success and keeps one row" do
    BetaSignup.create!(
      email: "join@example.com",
      source_path: "/",
      user_agent: ANDROID_UA,
      device: "android"
    )

    assert_no_difference "BetaSignup.count" do
      post beta_signups_path,
           params: { beta_signup: { email: "JOIN@example.com", source_path: "/" } },
           headers: { "HTTP_REFERER" => root_url },
           as: :turbo_stream
    end

    assert_response :success
    assert_includes response.body, I18n.t("beta_card.success")
  end

  test "honeypot responds success and saves nothing" do
    assert_no_difference "BetaSignup.count" do
      post beta_signups_path,
           params: {
             beta_signup: {
               email: "bot@example.com",
               source_path: "/",
               company: "https://spam.example"
             }
           },
           as: :turbo_stream
    end

    assert_response :success
    assert_includes response.body, I18n.t("beta_card.success")
  end

  test "invalid email returns inline error on turbo stream" do
    assert_no_difference "BetaSignup.count" do
      post beta_signups_path,
           params: { beta_signup: { email: "not-an-email", source_path: "/" } },
           as: :turbo_stream
    end

    assert_response :unprocessable_entity
    assert_match(/beta-signup-card/, response.body)
    assert_match(/lp-beta-card__error/, response.body)
  end

  test "rate limit blocks after five posts in a minute" do
    5.times do |i|
      post beta_signups_path,
           params: { beta_signup: { email: "one#{i}@example.com", source_path: "/" } },
           headers: { "HTTP_REFERER" => root_url },
           as: :html
      assert_redirected_to root_path
    end

    post beta_signups_path,
         params: { beta_signup: { email: "six@example.com", source_path: "/" } },
         headers: { "HTTP_REFERER" => root_url },
         as: :html

    assert_redirected_to root_path
    assert_equal I18n.t("beta_card.rate_limited"), flash[:alert]
    assert_equal 5, BetaSignup.count
  end

  test "html create redirects back with success flash" do
    post beta_signups_path,
         params: { beta_signup: { email: "html@example.com", source_path: "/" } },
         headers: { "HTTP_REFERER" => root_url, "User-Agent" => ANDROID_UA },
         as: :html

    assert_redirected_to root_path
    assert_equal I18n.t("beta_card.success"), flash[:notice]
  end
end
