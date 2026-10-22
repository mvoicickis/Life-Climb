# frozen_string_literal: true

require "test_helper"

class CsrfAuthenticationTest < ActionDispatch::IntegrationTest
  setup do
    @previous_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @previous_forgery_protection
  end

  test "stale CSRF on signup redirects with alert and prefilled email without creating user" do
    email = "csrf-signup@example.com"

    get new_registration_path
    assert_response :success

    assert_no_difference("User.count") do
      post registration_path, params: {
        authenticity_token: "stale",
        user: {
          name: "Test User",
          email_address: email,
          password: "password12345",
          password_confirmation: "password12345"
        }
      }
    end

    assert_redirected_to new_registration_path
    assert_equal I18n.t("auth.csrf_signup_retry"), flash[:alert]

    follow_redirect!
    assert_response :success
    assert_select "input[name='user[email_address]'][value=?]", email
  end

  test "stale CSRF on login redirects with alert and prefilled email without session cookie" do
    user = users(:one)
    email = user.email_address

    get new_session_path
    assert_response :success

    post session_path, params: {
      authenticity_token: "stale",
      email_address: email,
      password: "password12345"
    }

    assert_redirected_to new_session_path
    assert cookies[:session_id].blank?
    assert_equal I18n.t("auth.csrf_login_retry"), flash[:alert]

    follow_redirect!
    assert_response :success
    assert_select "input[name='email_address'][value=?]", email
  end
end
