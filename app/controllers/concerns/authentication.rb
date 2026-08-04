# frozen_string_literal: true

module Authentication
  extend ActiveSupport::Concern

  SESSION_TTL = 30.days
  PENDING_2FA_TTL = 10.minutes

  included do
    before_action :require_authentication
    helper_method :authenticated?
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private
    def authenticated?
      resume_session
    end

    def require_authentication
      resume_session || request_authentication
    end

    def resume_session
      Current.session ||= find_valid_session_by_cookie
    end

    def find_valid_session_by_cookie
      return unless cookies.signed[:session_id]

      record = Session.find_by(id: cookies.signed[:session_id])
      return unless record
      return expire_and_clear_session!(record) if session_expired?(record)

      record.touch if record.updated_at < 1.hour.ago
      record
    end

    def session_expired?(record)
      record.created_at < SESSION_TTL.ago || record.updated_at < SESSION_TTL.ago
    end

    def expire_and_clear_session!(record)
      record.destroy
      cookies.delete(:session_id, same_site: :lax, secure: Rails.env.production?)
      nil
    end

    def request_authentication
      session[:return_to_after_authenticating] = safe_return_path
      redirect_to new_session_path
    end

    # Only allow relative in-app paths (prevent open redirects).
    def safe_return_path
      path = request.fullpath.to_s
      return nil if path.blank?
      return nil unless path.start_with?("/") && !path.start_with?("//")
      return nil if path.start_with?("/session", "/registration", "/passwords", "/two_factor_session")

      path
    end

    def after_authentication_url
      stored = session.delete(:return_to_after_authenticating)
      if stored.present? && stored.start_with?("/") && !stored.start_with?("//")
        return stored
      end
      return admin_root_path if Current.user&.admin?
      return onboarding_path if Current.user&.needs_onboarding?

      dashboard_path
    end

    def start_new_session_for(user)
      # Session fixation: rotate Rails session id on login; preserve safe return path.
      return_to = session[:return_to_after_authenticating]
      reset_session
      session[:return_to_after_authenticating] = return_to if return_to.present?

      user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |sess|
        Current.session = sess
        cookies.signed[:session_id] = {
          value: sess.id,
          httponly: true,
          same_site: :lax,
          secure: Rails.env.production?,
          expires: SESSION_TTL.from_now
        }
      end
    end

    def terminate_session
      Current.session&.destroy
      cookies.delete(:session_id, same_site: :lax, secure: Rails.env.production?)
      Current.reset
      reset_session
    end

    def stash_pending_2fa!(user)
      session[:pending_2fa_user_id] = user.id
      session[:pending_2fa_at] = Time.current.to_i
    end

    def clear_pending_2fa!
      session.delete(:pending_2fa_user_id)
      session.delete(:pending_2fa_at)
    end

    def pending_2fa_user
      user_id = session[:pending_2fa_user_id]
      started = session[:pending_2fa_at].to_i
      return if user_id.blank? || started.zero?

      if started < PENDING_2FA_TTL.ago.to_i
        clear_pending_2fa!
        return nil
      end

      User.find_by(id: user_id)
    end
end
