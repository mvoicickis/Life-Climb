# frozen_string_literal: true

module Notifications
  class BaseController < ApplicationController
    allow_unauthenticated_access
    skip_forgery_protection
    skip_onboarding_check

    before_action :authenticate_notification_token!

    private

    def authenticate_notification_token!
      @user = User.find_signed(params[:token].to_s, purpose: :notification_action)
      return if @user

      render json: { ok: false, error: I18n.t("notifications.actions.unauthorized") }, status: :unauthorized
    end
  end
end
