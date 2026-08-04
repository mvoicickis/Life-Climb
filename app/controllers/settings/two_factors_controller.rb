# frozen_string_literal: true

module Settings
  # Enable / disable TOTP for admin and developer accounts (Phase A: optional).
  class TwoFactorsController < ApplicationController
    skip_onboarding_check
    before_action :require_privileged_for_2fa!
    before_action :reject_impersonation!

    def show
      @backup_codes = Array(session.delete(:otp_backup_codes_plaintext))
    end

    def create
      current_user.begin_otp_setup!
      redirect_to settings_two_factor_path, notice: t("two_factor.setup_started")
    end

    def confirm
      codes = current_user.confirm_otp_setup!(params[:code])
      session[:otp_backup_codes_plaintext] = codes
      redirect_to settings_two_factor_path, notice: t("two_factor.enabled")
    rescue RuntimeError => e
      redirect_to settings_two_factor_path, alert: e.message
    end

    def regenerate_backup_codes
      codes = current_user.regenerate_otp_backup_codes!(params[:code])
      session[:otp_backup_codes_plaintext] = codes
      redirect_to settings_two_factor_path, notice: t("two_factor.backup_codes_regenerated")
    rescue RuntimeError => e
      redirect_to settings_two_factor_path, alert: e.message
    end

    def destroy
      current_user.disable_otp!(params[:code])
      session.delete(:otp_backup_codes_plaintext)
      redirect_to settings_two_factor_path, notice: t("two_factor.disabled")
    rescue RuntimeError => e
      redirect_to settings_two_factor_path, alert: e.message
    end

    private

    def require_privileged_for_2fa!
      return if current_user&.privileged_for_2fa?

      redirect_to settings_path, alert: t("two_factor.not_available")
    end

    def reject_impersonation!
      return unless impersonating?

      redirect_to settings_path, alert: t("two_factor.not_while_impersonating")
    end
  end
end
