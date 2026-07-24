require "application_system_test_case"

class LifepointsTest < ApplicationSystemTestCase
  test "sign in, open card, save more than yesterday" do
    user = users(:one)
    habit = habits(:one)
    habit.daily_logs.create!(user: user, logged_on: Date.yesterday, amount: 6, goal: 6)

    visit new_session_path
    fill_in "Email", with: user.email_address
    fill_in "Password", with: "password"
    click_button "Sign in"

    assert_text "Home"
    assert_text "Drink water"

    visit habit_path(habit)
    assert_text "How many today?"

    page.execute_script(<<~JS)
      document.getElementById("daily_log_amount").value = "8";
      document.querySelector("form[action*='daily_logs']").submit();
    JS

    assert_text "More than yesterday"
    assert_text "UP"
  end
end
