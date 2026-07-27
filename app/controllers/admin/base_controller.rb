# frozen_string_literal: true

module Admin
  class BaseController < ApplicationController
    layout "admin"
    skip_onboarding_check
    before_action :require_admin!

    private

    def require_admin!
      unless current_user
        request_authentication
        return
      end

      promote_configured_admin_if_needed!

      # Impersonation swaps Current.user to the target account. Only the stop
      # action may proceed without an admin Current.user.
      return if current_user.admin? && !impersonating?

      deny_admin_access!
    end

    def promote_configured_admin_if_needed!
      email = ENV["ADMIN_EMAIL"].to_s.strip.downcase.presence
      return if email.blank?
      return unless current_user.email_address == email
      return if current_user.admin?

      current_user.update_columns(admin: true)
    end

    def deny_admin_access!
      if request.format.html?
        redirect_to dashboard_path, alert: t("admin.access_denied")
      else
        head :forbidden
      end
    end

    def true_admin
      return current_user if current_user&.admin? && !impersonating?

      User.find_by(id: session[:admin_impersonator_id], admin: true)
    end
  end
end
