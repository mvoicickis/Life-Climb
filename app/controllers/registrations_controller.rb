class RegistrationsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 5, within: 15.minutes, only: :create, with: -> { redirect_to new_registration_path, alert: "Too many attempts. Try again later." }

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    if @user.save
      capture_signup_time_zone!
      start_new_session_for @user
      redirect_to v2_onboarding_path(step: "character"), notice: t("v2_onboarding.signed_up")
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:name, :email_address, :password, :password_confirmation)
  end

  def capture_signup_time_zone!
    zone = params[:time_zone].to_s.strip
    return if zone.blank?
    return unless valid_iana_time_zone?(zone)

    @user.create_notification_preference!(time_zone: zone)
  rescue ActiveRecord::RecordInvalid
    # Signup must not fail if preference creation fails.
  end

  def valid_iana_time_zone?(zone)
    TZInfo::Timezone.get(zone)
    true
  rescue TZInfo::InvalidTimezoneIdentifier
    false
  end
end
