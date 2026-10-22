# frozen_string_literal: true

require "test_helper"

class AuthPagesAccessTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test "logged in user visiting sign in is redirected without flash" do
    sign_in_as(@user)

    get new_session_path

    assert_redirected_to dashboard_url
    assert flash.empty?
  end

  test "logged in user visiting registration is redirected without flash" do
    sign_in_as(@user)

    get new_registration_path

    assert_redirected_to dashboard_url
    assert flash.empty?
  end

  test "logged out sign in page renders form and turbo no cache meta" do
    get new_session_path

    assert_response :success
    assert_select "form[action=?]", session_path
    assert_select "meta[name=turbo-cache-control][content=?]", "no-cache"
  end

  test "logged out registration page renders form and turbo no cache meta" do
    get new_registration_path

    assert_response :success
    assert_select "form[action=?]", registration_path
    assert_select "meta[name=turbo-cache-control][content=?]", "no-cache"
  end

  test "settings sign out form disables turbo drive" do
    sign_in_as(@user)

    get settings_path

    assert_response :success
    assert_select "form[action=?][data-turbo=?]", session_path, "false"
    assert_match(/offline-page-cache#clearBeforeSignOut/, response.body)
  end
end
