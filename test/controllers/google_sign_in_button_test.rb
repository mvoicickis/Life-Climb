# frozen_string_literal: true

require "test_helper"

class GoogleSignInButtonTest < ActionDispatch::IntegrationTest
  MESSENGER_UA = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 [FBAN/MessengerForiOS;FBAV/450.0.0.0.0;]"

  test "shows continue with google when oauth is configured" do
    with_google_oauth_configured do
      get new_session_path

      assert_response :success
      assert_select "form[action=?][data-turbo=?]", "/auth/google_oauth2", "false"
      assert_select ".lp-auth-google-btn", count: 1
      assert_match I18n.t("auth.continue_with_google"), response.body
      assert_select ".lp-auth-or", count: 1
    end
  end

  test "hides google sign in when client id is missing" do
    without_google_oauth_configured do
      get new_session_path

      assert_response :success
      assert_select "form[action=?]", "/auth/google_oauth2", count: 0
      assert_select ".lp-auth-google-btn", count: 0
      assert_select ".lp-auth-or", count: 0
    end
  end

  test "in app browser shows hint instead of google button" do
    with_google_oauth_configured do
      get new_session_path, headers: { "HTTP_USER_AGENT" => MESSENGER_UA }

      assert_response :success
      assert_select "form[action=?]", "/auth/google_oauth2", count: 0
      assert_select ".lp-auth-google-hint", text: I18n.t("auth.google_open_in_browser")
      assert_select ".lp-auth-or", count: 0
      assert_select "form[action=?]", session_path
    end
  end

  private

  def with_google_oauth_configured
    with_env("GOOGLE_CLIENT_ID" => "test-client-id", "GOOGLE_CLIENT_SECRET" => "test-client-secret") { yield }
  end

  def without_google_oauth_configured
    with_env("GOOGLE_CLIENT_ID" => nil, "GOOGLE_CLIENT_SECRET" => nil) { yield }
  end

  def with_env(overrides)
    previous = overrides.keys.index_with { |key| ENV[key] }
    overrides.each { |key, value| ENV[key] = value }
    yield
  ensure
    previous.each { |key, value| ENV[key] = value }
  end
end
