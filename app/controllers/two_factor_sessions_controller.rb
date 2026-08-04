# frozen_string_literal: true

# Second step of sign-in for privileged accounts with OTP enabled.
class TwoFactorSessionsController < ApplicationController
  allow_unauthenticated_access
  skip_onboarding_check
  rate_limit to: 15, within: 3.minutes, only: :create, with: -> {
    redirect_to new_two_factor_session_path, alert: I18n.t("two_factor.try_again_later")
  }

  before_action :require_pending_2fa_user!

  def new
  end

  def create
    code = params[:code].to_s

    if @pending_user.verify_otp!(code) || @pending_user.verify_backup_code!(code)
      clear_pending_2fa!
      start_new_session_for @pending_user
      redirect_to after_authentication_url
    else
      redirect_to new_two_factor_session_path, alert: t("two_factor.invalid_code")
    end
  end

  def destroy
    clear_pending_2fa!
    redirect_to new_session_path, status: :see_other, notice: t("two_factor.cancelled")
  end

  private

  def require_pending_2fa_user!
    @pending_user = pending_2fa_user
    return if @pending_user&.privileged_for_2fa? && @pending_user.otp_enabled?

    clear_pending_2fa!
    redirect_to new_session_path, alert: t("two_factor.session_expired")
  end
end
