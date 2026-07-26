require "application_system_test_case"

class LifepointsTest < ApplicationSystemTestCase
  test "sign in reaches home with greeting" do
    user = users(:one)

    visit new_session_path
    fill_in "Email", with: user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"

    assert_text "LifePoints"
    assert_text user.display_name
  end
end
