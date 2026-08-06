# frozen_string_literal: true

require "test_helper"

class LocalesControllerTest < ActionDispatch::IntegrationTest
  teardown { I18n.locale = I18n.default_locale }

  test "signed-in locale change persists on user and applies after fresh session" do
    user = users(:one)
    seed_climb!(user)
    assert_nil user.locale

    sign_in_as user
    patch locale_path(locale: :ru)
    assert_redirected_to dashboard_path
    assert_equal "ru", user.reload.locale

    sign_out
    reset!
    I18n.locale = I18n.default_locale

    sign_in_as user
    get settings_path
    assert_response :success
    assert_select "html[lang=?]", "ru"
    assert_match(/Настройки|Язык|Русский/, response.body)
  end

  test "can switch locale to russian" do
    user = users(:one)
    seed_climb!(user)
    sign_in_as user
    patch locale_path(locale: :ru)
    assert_redirected_to dashboard_path
    follow_redirect!
    assert_response :success
    get settings_path
    assert_match(/Ты/, response.body)
  end

  test "guest locale switch does not require user record" do
    patch locale_path(locale: :de)
    assert_response :redirect
    follow_redirect!
    assert_response :success
  end

  test "can switch locale to latvian" do
    user = users(:one)
    seed_climb!(user)
    sign_in_as user
    patch locale_path(locale: :lv)
    assert_redirected_to dashboard_path
    follow_redirect!
    assert_response :success
    get settings_path
    assert_match(/Tu/, response.body)
  end

  test "can switch locale to german" do
    user = users(:one)
    seed_climb!(user)
    sign_in_as user
    patch locale_path(locale: :de)
    assert_redirected_to dashboard_path
    follow_redirect!
    assert_response :success
    assert_match(/Heute|Berg|Du/, response.body)
    get settings_path
    assert_match(/Du/, response.body)
  end

  test "can switch locale to spanish" do
    user = users(:one)
    seed_climb!(user)
    sign_in_as user
    patch locale_path(locale: :es)
    assert_redirected_to dashboard_path
    follow_redirect!
    assert_response :success
    get settings_path
    assert_match(/Tú/, response.body)
  end
end
