# frozen_string_literal: true

require "test_helper"

class UserOtpTest < ActiveSupport::TestCase
  setup do
    @admin = users(:admin)
    @user = users(:one)
  end

  test "privileged_for_2fa includes admin and developer flag" do
    assert @admin.privileged_for_2fa?
    refute @user.privileged_for_2fa?

    @user.update_columns(developer: true)
    assert @user.reload.privileged_for_2fa?
  end

  test "privileged_for_2fa includes DeveloperAccess env whitelist" do
    previous = ENV["DEVELOPER_EMAIL"]
    ENV["DEVELOPER_EMAIL"] = @user.email_address
    begin
      assert @user.privileged_for_2fa?
    ensure
      if previous
        ENV["DEVELOPER_EMAIL"] = previous
      else
        ENV.delete("DEVELOPER_EMAIL")
      end
    end
  end

  test "otp enable confirm and verify" do
    @admin.begin_otp_setup!
    refute @admin.otp_enabled?

    code = @admin.totp.now
    backup_codes = @admin.confirm_otp_setup!(code)

    assert @admin.reload.otp_enabled?
    assert_equal UserOtp::BACKUP_CODE_COUNT, backup_codes.size
    assert @admin.verify_otp!(@admin.totp.now)
  end

  test "backup codes are single-use" do
    @admin.begin_otp_setup!
    codes = @admin.confirm_otp_setup!(@admin.totp.now)
    used = codes.first

    assert @admin.verify_backup_code!(used)
    refute @admin.verify_backup_code!(used)
  end

  test "otp verify tolerates about one window of clock skew" do
    @admin.begin_otp_setup!
    @admin.confirm_otp_setup!(@admin.totp.now)

    skewed_code = @admin.totp.at(Time.now.to_i - 25)
    assert @admin.verify_otp!(skewed_code), "expected code from ~25s ago to verify with OTP_DRIFT=#{UserOtp::OTP_DRIFT}"
  end

  test "regular user cannot begin otp setup" do
    assert_raises(RuntimeError) { @user.begin_otp_setup! }
  end
end
