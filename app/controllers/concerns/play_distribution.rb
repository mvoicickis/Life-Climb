# frozen_string_literal: true

module PlayDistribution
  extend ActiveSupport::Concern

  PLAY_DISTRIBUTION_COOKIE = :lp_distribution
  PLAY_DISTRIBUTION_VALUE = "play"
  DEFAULT_PLAY_PACKAGE_NAME = "app.lifeclimb"

  included do
    before_action :remember_play_distribution
    helper_method :play_app?
  end

  def play_app?
    cookies[PLAY_DISTRIBUTION_COOKIE] == PLAY_DISTRIBUTION_VALUE
  end

  private

  def remember_play_distribution
    return unless params[:distribution] == PLAY_DISTRIBUTION_VALUE || android_app_referrer?

    set_play_distribution_cookie!
  end

  def set_play_distribution_cookie!
    cookies.permanent[PLAY_DISTRIBUTION_COOKIE] = {
      value: PLAY_DISTRIBUTION_VALUE,
      httponly: true,
      same_site: :lax,
      secure: Rails.env.production?
    }
  end

  def android_app_referrer?
    referer = request.referer.to_s
    return false if referer.blank?

    prefix = "android-app://#{play_package_name}"
    referer == prefix || referer.start_with?("#{prefix}/")
  end

  def play_package_name
    ENV["PLAY_PACKAGE_NAME"].to_s.strip.presence || DEFAULT_PLAY_PACKAGE_NAME
  end

  def redirect_if_play_app!
    redirect_to dashboard_path if play_app?
  end

  def head_not_found_if_play_app!
    head :not_found if play_app?
  end
end
