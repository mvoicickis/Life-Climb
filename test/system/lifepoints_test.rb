require "application_system_test_case"

class LifepointsTest < ApplicationSystemTestCase
  include ActionView::RecordIdentifier

  test "sign in, create habit, complete it, and earn points" do
    visit new_session_path

    fill_in "Email", with: users(:one).email_address
    fill_in "Password", with: "password"
    click_button "Sign in"

    assert_text "Dashboard"
    assert_text "Drink water"

    visit new_habit_path
    assert_text "New habit"

    page.execute_script(<<~JS)
      document.getElementById("habit_name").value = "Evening walk";
      document.getElementById("habit_description").value = "Walk around the block";
      document.getElementById("habit_points").value = "8";
      document.getElementById("habit_frequency").value = "daily";
      document.getElementById("habit_active").checked = true;
      document.querySelector("form[action='/habits']").submit();
    JS

    assert_text "Habit created"
    assert_text "Evening walk"

    visit root_path
    assert_text "Evening walk"

    habit = Habit.find_by!(name: "Evening walk", user_id: users(:one).id)
    page.execute_script(<<~JS)
      document.querySelector("##{dom_id(habit)} form").submit();
    JS

    assert_text "Done today"
    assert_selector "#dashboard-stats", text: "8"
  end
end
