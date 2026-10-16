class ApplicationController < ActionController::Base
  include PlayDistribution
  include Authentication
  include SetLocale
  include RequireOnboarding
  include AdminImpersonationReadOnly
  include OfflinePageCacheHeaders

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_user, :impersonating?, :read_only_impersonation?, :announcement_banner, :developer?

  before_action :enforce_maintenance_mode
  after_action :track_app_opened_if_eligible

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
    return if controller_path == "legal"
    return if controller_path == "rails/health"
    return if controller_path == "play/asset_links"

    render template: "shared/maintenance", layout: "application", status: :service_unavailable
  end

  def true_admin_session?
    User.exists?(id: session[:admin_impersonator_id], admin: true)
  end

  def onboarding_entry_path
    user = Current.user || current_user
    user&.planning_v2? ? v2_onboarding_path : onboarding_path
  end

  def track_app_opened_if_eligible
    return unless app_open_tracking_eligible?

    Analytics::TrackAppOpened.call(user: current_user)
  rescue StandardError => e
    Rails.logger.warn("[AppOpened] user=#{current_user&.id} #{e.class}: #{e.message}")
  end

  def app_open_tracking_eligible?
    user = current_user
    return false if user.blank?
    return false unless request.get? || request.head?
    return false unless request.format.html?
    return false if request.format.turbo_stream?
    return false if impersonating?
    return false if app_open_prefetch_request?
    return false unless app_open_trackable_action?
    return false if user.next_app_open_at.present? && Time.current < user.next_app_open_at

    true
  end

  def app_open_prefetch_request?
    [ request.headers["X-Sec-Purpose"], request.headers["Purpose"] ].compact.any? do |value|
      value.to_s.include?("prefetch")
    end
  end

  def app_open_trackable_action?
    (controller_path == "dashboard" && action_name == "show") ||
      (controller_path == "life_journeys" && action_name == "show")
  end
end
