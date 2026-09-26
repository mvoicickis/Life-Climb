# frozen_string_literal: true

require "application_system_test_case"

class YouSignOutTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @user.update!(character: "fox", planning_version: 2)
    @user.mark_companion_pick_done!
    page.driver.browser.manage.window.resize_to(390, 844)
  end

  test "sign out on You clears session and lands on sign in" do
    sign_in_browser!(@user)

    visit settings_path
    assert_selector "form[action='#{session_path}'] .lp-you-signout", wait: 5
    click_button "Sign out"

    assert_current_path new_session_path, wait: 10
    assert_button "Sign in"
    assert_nil page.driver.browser.manage.all_cookies.find { |c| c[:name] == "session_id" }
  end

  private

  def sign_in_browser!(user)
    session = user.sessions.create!
    jar = ActionDispatch::TestRequest.create.cookie_jar
    jar.signed[:session_id] = session.id

    visit new_session_path
    page.driver.browser.manage.add_cookie(
      name: "session_id",
      value: jar[:session_id],
      path: "/"
    )
  end
end
