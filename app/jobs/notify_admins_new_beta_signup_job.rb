# frozen_string_literal: true

class NotifyAdminsNewBetaSignupJob < ApplicationJob
  queue_as :default

  def perform(beta_signup_id)
    signup = BetaSignup.find_by(id: beta_signup_id)
    return unless signup

    body = push_body_for(signup)
    payload = {
      "title" => I18n.t("notifications.admin_beta_signup_push.title"),
      "body" => body,
      "url" => "/admin/beta_signups",
      "kind" => "admin_beta_signup",
      "tag" => "beta-signup-#{signup.id}"
    }

    admin_recipients.find_each do |admin|
      SendWebPushJob.perform_later(admin.id, payload)
    end
  end

  private

  def admin_recipients
    User.where(admin: true).where(id: PushSubscription.select(:user_id))
  end

  def push_body_for(signup)
    body = signup.email
    android = Admin::DeviceFromUserAgent::DEVICE_ANDROID.to_s
    body = "#{body}#{I18n.t('notifications.admin_beta_signup_push.android_suffix')}" if signup.device == android
    body
  end
end
