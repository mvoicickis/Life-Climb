require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  test "update how many stats to show" do
    user = users(:one)
    sign_in_as user

    patch settings_path, params: { user: { home_stat_count: 3 } }
    assert_redirected_to settings_path
    assert_equal 3, user.reload.home_stat_count
  end

  test "show make it yours rows" do
    user = users(:one)
    sign_in_as user

    get settings_path
    assert_response :success
    assert_select "a[href=?]", edit_today_count_settings_path
    assert_select "a[href=?]", edit_name_settings_path
    assert_select "a[href=?]", life_area_selections_path
    assert_select "a[href=?]", support_path
    assert_select "a[href=?]", new_password_path
  end

  test "edit name page and update" do
    user = users(:one)
    sign_in_as user

    get edit_name_settings_path
    assert_response :success

    patch settings_path, params: { user: { name: "Alex" } }
    assert_redirected_to settings_path
    assert_equal "Alex", user.reload.name
  end

  test "edit today count page" do
    user = users(:one)
    sign_in_as user

    get edit_today_count_settings_path
    assert_response :success
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
