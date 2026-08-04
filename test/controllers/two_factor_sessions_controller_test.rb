# frozen_string_literal: true

require "test_helper"

class TwoFactorSessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @user = users(:one)
  end

  test "regular user login is unchanged one step" do
    post session_path, params: { email_address: @user.email_address, password: "password12345" }

    assert_redirected_to dashboard_url
    assert cookies[:session_id]
  end

  test "admin without otp enabled logs in normally" do
    refute @admin.otp_enabled?

    post session_path, params: { email_address: @admin.email_address, password: "password12345" }

    assert_redirected_to admin_root_url
    assert cookies[:session_id]
  end

  test "admin with otp enabled is challenged before session starts" do
    enable_otp!(@admin)

    post session_path, params: { email_address: @admin.email_address, password: "password12345" }

    assert_redirected_to new_two_factor_session_path
    assert_empty cookies[:session_id].to_s

    follow_redirect!
    assert_response :success
    assert_match(/authenticator/i, response.body)
  end

  test "admin with otp enabled signs in with correct totp" do
    enable_otp!(@admin)

    post session_path, params: { email_address: @admin.email_address, password: "password12345" }
    post two_factor_session_path, params: { code: @admin.totp.now }

    assert_redirected_to admin_root_url
    assert cookies[:session_id]
  end

  test "admin with otp enabled is blocked by wrong code" do
    enable_otp!(@admin)

    post session_path, params: { email_address: @admin.email_address, password: "password12345" }
    post two_factor_session_path, params: { code: "000000" }

    assert_redirected_to new_two_factor_session_path
    assert_empty cookies[:session_id].to_s
  end

  test "backup code works once at login" do
    enable_otp!(@admin)
    backup = @admin.send(:generate_backup_code_list).first
    @admin.update!(otp_backup_codes_digest: [ @admin.send(:digest_backup_code, backup) ])

    post session_path, params: { email_address: @admin.email_address, password: "password12345" }
    post two_factor_session_path, params: { code: backup }
    assert_redirected_to admin_root_url
    assert cookies[:session_id].present?

    delete session_path
    assert_empty cookies[:session_id].to_s

    post session_path, params: { email_address: @admin.email_address, password: "password12345" }
    post two_factor_session_path, params: { code: backup }
    assert_redirected_to new_two_factor_session_path
    assert_empty cookies[:session_id].to_s
  end

  private

  def enable_otp!(user)
    user.begin_otp_setup!
    user.confirm_otp_setup!(user.totp.now)
  end
end
