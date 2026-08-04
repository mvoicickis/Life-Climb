require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  test "update how many stats to show" do
    user = users(:one)
    sign_in_as user

    patch settings_path, params: { user: { home_stat_count: 3 } }
    assert_redirected_to settings_path(highlight: "today_count")
    assert_equal 3, user.reload.home_stat_count
  end

  test "show make it yours rows" do
    user = users(:one)
    sign_in_as user

    get settings_path
    assert_response :success
    assert_select "h1", text: "You"
    assert_select "a[href=?]", edit_today_count_settings_path, count: 0
    assert_select "a#you-row-today-count", count: 0
    assert_select "a[href=?]", edit_name_settings_path
    assert_select "a#you-row-life-area", count: 0
    assert_select "#you-character"
    assert_select "#you-character input[name='user[character]'][value=man]"
    assert_select "#you-character input[name='user[character]'][value=woman]"
    assert_select "#you-character img[src*='character-man']"
    assert_select "#you-character img[src*='character-woman']"
    assert_select "#you-theme"
    assert_select "#you-theme .lp-theme-switch__btn.is-active", text: "Light"
    assert_select "html[data-theme=light]"
    assert_select "#you-language"
    assert_select "#you-language form[action=?]", locale_path(locale: :en)
    assert_select "#you-language form[action=?]", locale_path(locale: :ru)
    assert_select "a[href=?]", support_path
    assert_select "a[href=?]", new_password_path
    assert_select "a[href=?]", about_path, count: 0
    assert_select "a[href=?]", new_feedback_path
  end

  test "update theme to dark and back to light" do
    user = users(:one)
    sign_in_as user
    assert_equal "light", user.theme

    patch settings_path, params: { user: { theme: "dark" } }
    assert_redirected_to settings_path(highlight: "theme")
    assert_equal "dark", user.reload.theme

    follow_redirect!
    assert_select "html[data-theme=dark]"
    assert_select "#you-theme .lp-theme-switch__btn.is-active", text: "Dark"
    assert_match(/name="theme-color" content="#0b0f14"/, response.body)

    patch settings_path, params: { user: { theme: "light" } }
    assert_redirected_to settings_path(highlight: "theme")
    assert_equal "light", user.reload.theme

    follow_redirect!
    assert_select "html[data-theme=light]"
    assert_match(/name="theme-color" content="#f8fafc"/, response.body)
  end

  test "rejects invalid theme" do
    user = users(:one)
    sign_in_as user

    patch settings_path, params: { user: { theme: "neon" } }
    assert_response :unprocessable_entity
    assert_equal "light", user.reload.theme
  end

  test "update character from settings" do
    user = users(:one)
    sign_in_as user
    assert_nil user.character

    patch settings_path, params: { user: { character: "woman" } }
    assert_redirected_to settings_path(highlight: "character")
    assert_equal "woman", user.reload.character
    assert_equal "characters/character-woman.png", user.character_image
  end

  test "edit name page and update" do
    user = users(:one)
    sign_in_as user

    get edit_name_settings_path
    assert_response :success

    patch settings_path, params: { user: { name: "Alex" } }
    assert_redirected_to settings_path(highlight: "name")
    assert_equal "Alex", user.reload.name
  end

  test "edit today count page" do
    user = users(:one)
    sign_in_as user

    get edit_today_count_settings_path
    assert_response :success
    assert_select "[data-controller='number-stepper']"
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
