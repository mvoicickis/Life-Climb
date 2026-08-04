class ApplicationController < ActionController::Base
  include Authentication
  include SetLocale
  include RequireOnboarding

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_user, :impersonating?, :announcement_banner, :developer?

  before_action :enforce_maintenance_mode

  private

  def current_user
    Current.user
  end

  def developer?
    current_user&.developer?
  end

  def impersonating?
    session[:admin_impersonator_id].present?
  end

  def announcement_banner
    AppSetting.announcement_banner
  end

  def enforce_maintenance_mode
    return unless AppSetting.maintenance_mode?
    return if current_user&.admin?
    return if impersonating? && true_admin_session?
    return if controller_path.start_with?("admin")
    return if controller_name.in?(%w[sessions passwords registrations locales two_factor_sessions])
    return if controller_path == "rails/health"

    render template: "shared/maintenance", layout: "application", status: :service_unavailable
  end

  def true_admin_session?
    User.exists?(id: session[:admin_impersonator_id], admin: true)
  end
end
