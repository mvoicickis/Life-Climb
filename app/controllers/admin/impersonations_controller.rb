# frozen_string_literal: true

module Admin
  class ImpersonationsController < BaseController
    skip_before_action :require_admin!, only: :destroy
    before_action :require_true_admin_for_stop!, only: :destroy

    def create
      target = User.find(params[:user_id])
      if target.admin?
        redirect_to admin_user_path(target), alert: t("admin.impersonation.cannot_impersonate_admin") and return
      end

      impersonator_id = current_user.id
      terminate_session
      start_new_session_for(target)
      # terminate_session / start_new_session_for reset the Rails session — set after.
      session[:admin_impersonator_id] = impersonator_id
      redirect_to dashboard_path, notice: t("admin.impersonation.started", name: target.display_name)
    end

    def destroy
      admin = User.find_by(id: session[:admin_impersonator_id], admin: true)
      terminate_session
      if admin
        start_new_session_for(admin)
        redirect_to admin_root_path, notice: t("admin.impersonation.stopped")
      else
        redirect_to new_session_path, alert: t("admin.access_denied")
      end
    end

    private

    def require_true_admin_for_stop!
      return if session[:admin_impersonator_id].present? &&
                User.exists?(id: session[:admin_impersonator_id], admin: true)

      deny_admin_access!
    end
  end
end
