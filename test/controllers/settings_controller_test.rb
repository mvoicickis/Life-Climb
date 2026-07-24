require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  test "update how many stats to show" do
    user = users(:one)
    sign_in_as user

    patch settings_path, params: { user: { home_stat_count: 3 } }
    assert_redirected_to settings_path
    assert_equal 3, user.reload.home_stat_count
  end

  test "reorder home habits for current user only" do
    user = users(:one)
    sign_in_as user
    a = user.habits.create!(name: "A", unit: "times", points: 5, frequency: "daily", show_on_home: true, position: 1)
    b = user.habits.create!(name: "B", unit: "times", points: 5, frequency: "daily", show_on_home: true, position: 2)

    patch reorder_settings_path, params: { habit_ids: [ b.id, a.id ] }, as: :json
    assert_response :success
    assert_equal 1, b.reload.position
    assert_equal 2, a.reload.position
  end
end
