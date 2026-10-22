# frozen_string_literal: true

class OmniauthCallbacksController < ApplicationController
  allow_unauthenticated_access only: %i[ google_oauth2 failure ]

  def google_oauth2
    auth = request.env["omniauth.auth"]
    return google_sign_in_failed! if auth.blank?

    result = Auth::GoogleSignIn.call(auth)
    return google_sign_in_failed! unless result.ok?

    complete_sign_in!(result.user, new_account: result.new_account)
  end

  def failure
    google_sign_in_failed!
  end

  private

  def google_sign_in_failed!
    redirect_to new_session_path, alert: t("auth.google_sign_in_failed")
  end
end
