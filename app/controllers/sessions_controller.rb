class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Try again later." }

  def new
  end

  def create
    if user = User.authenticate_by(params.permit(:email_address, :password))
      promote_configured_admin!(user)

      if user.privileged_for_2fa? && user.otp_enabled?
        stash_pending_2fa!(user)
        redirect_to new_two_factor_session_path
        return
      end

      clear_pending_2fa!
      start_new_session_for user
      redirect_to after_authentication_url
    else
      redirect_to new_session_path, alert: "Try another email address or password."
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other
  end

  private

  def promote_configured_admin!(user)
    email = ENV["ADMIN_EMAIL"].to_s.strip.downcase.presence
    return if email.blank?
    return unless user.email_address == email
    return if user.admin?

    user.update_columns(admin: true)
  end
end
