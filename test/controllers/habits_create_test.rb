require "test_helper"

class HabitsCreateTest < ActionDispatch::IntegrationTest
  test "create habit" do
    user = users(:one)
    sign_in_as user
    assert_difference "Habit.count", 1 do
      post habits_path, params: {
        habit: {
          name: "Evening walk",
          description: "Walk",
          points: 8,
          frequency: "daily",
          active: true,
          unit: "steps",
          show_on_home: true
        }
      }
    end
    assert_redirected_to dashboard_path
    follow_redirect!
    assert_match(/Added/, response.body)
  end
end
