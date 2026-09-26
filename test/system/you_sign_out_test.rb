# frozen_string_literal: true

require "application_system_test_case"

class YouSignOutTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    page.driver.browser.manage.window.resize_to(390, 844)
  end

  test "sign out on You clears session and lands on sign in" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_predicate page.driver.browser.manage.all_cookies.find { |c| c[:name] == "session_id" }, :present?

    visit settings_path
    assert_selector "form[action='#{session_path}'] .lp-you-signout", wait: 5
    click_button "Sign out"

    assert_current_path new_session_path, wait: 10
    assert_button "Sign in"
  end
end
