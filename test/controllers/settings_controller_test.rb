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
    assert_select "#you-character input[name='user[character]'][value=birdie]"
    assert_select "#you-character input[name='user[character]'][value=bee]"
    assert_select "#you-character input[name='user[character]'][value=bear]"
    assert_select "#you-character input[name='user[character]'][value=fox]"
    assert_select "#you-character input[name='user[character]'][value=horse]"
    assert_select "#you-character input[name='user[character]'][value=raven]"
    assert_select "#you-character img[src*='characters/fox']"
    assert_select "#you-theme"
    assert_select "#you-theme .lp-theme-switch__btn.is-active", text: "Light"
    assert_select "html[data-theme=light]"
    assert_select "#you-language"
    assert_select "#you-language form[action=?]", locale_path(locale: :en)
    assert_select "#you-language form[action=?]", locale_path(locale: :ru)
    assert_select "#you-reminders[data-controller=?]", "push-reminders"
    assert_select "#you-reminders button[data-action=?]", "click->push-reminders#enable"
    assert_select "#you-reminders button[data-action=?]", "click->push-reminders#sendTest"
    assert_select "a#you-row-notifications[href=?]", settings_notifications_path
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

    patch settings_path, params: { user: { character: "fox" } }
    assert_redirected_to settings_path(highlight: "character")
    assert_equal "fox", user.reload.character
    assert_equal "characters/fox.png", user.character_image
    assert user.companion_pick_done?
    refute user.needs_companion_pick?
  end

  test "legacy character users see companion re-pick prompt until they choose" do
    user = users(:one)
    user.update_columns(
      character: "man",
      onboarding_completed_at: Time.current,
      planning_version: 2
    )
    sign_in_as user
    seed_climb!(user)

    get dashboard_path
    assert_response :success
    assert_select "#companion-pick-prompt"
    assert_select "#companion-pick-prompt input[name='user[character]'][value=fox]"
    assert_select "#companion-pick-prompt input[name='user[character]'][value=raven]"

    patch settings_path, params: { user: { character: "bee" } }
    assert_redirected_to settings_path(highlight: "character")
    assert_equal "bee", user.reload.character
    refute user.needs_companion_pick?

    get dashboard_path
    assert_response :success
    assert_select "#companion-pick-prompt", count: 0
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
