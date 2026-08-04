# frozen_string_literal: true

require "test_helper"

class Settings::TwoFactorsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @user = users(:one)
  end

  test "non privileged cannot see setup routes" do
    ENV.delete("DEVELOPER_EMAIL")
    ENV.delete("DEVELOPER_EMAILS")
    @user.update_columns(admin: false, developer: false)
    sign_in_as(@user)

    get settings_two_factor_path
    assert_redirected_to settings_path

    post settings_two_factor_path
    assert_redirected_to settings_path

    get settings_path
    assert_response :success
    assert_select "section#you-two-factor", count: 0
    assert_select "a[href=?]", settings_two_factor_path, count: 0
  end

  test "admin sees setup entry on settings and can open page" do
    sign_in_as(@admin)

    get settings_path
    assert_response :success
    assert_match(/Two-factor authentication/, response.body)

    get settings_two_factor_path
    assert_response :success
    assert_match(/Protect this account|Set up|Start setup/i, response.body)
  end

  test "admin can enable otp through confirm" do
    sign_in_as(@admin)

    post settings_two_factor_path
    assert_redirected_to settings_two_factor_path
    @admin.reload
    refute @admin.otp_enabled?
    assert @admin.otp_secret_plain.present?

    post confirm_settings_two_factor_path, params: { code: @admin.totp.now }
    assert_redirected_to settings_two_factor_path
    assert @admin.reload.otp_enabled?

    follow_redirect!
    assert_match(/Backup codes/i, response.body)
  end
end
