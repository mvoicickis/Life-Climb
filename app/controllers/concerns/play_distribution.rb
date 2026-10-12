# frozen_string_literal: true

module PlayDistribution
  extend ActiveSupport::Concern

  PLAY_DISTRIBUTION_COOKIE = :lp_distribution
  PLAY_DISTRIBUTION_VALUE = "play"

  included do
    before_action :remember_play_distribution
    helper_method :play_app?
  end

  def play_app?
    cookies[PLAY_DISTRIBUTION_COOKIE] == PLAY_DISTRIBUTION_VALUE
  end

  private

  def remember_play_distribution
    return unless params[:distribution] == PLAY_DISTRIBUTION_VALUE

    cookies.permanent[PLAY_DISTRIBUTION_COOKIE] = {
      value: PLAY_DISTRIBUTION_VALUE,
      httponly: true,
      same_site: :lax,
      secure: Rails.env.production?
    }
  end

  def redirect_if_play_app!
    redirect_to dashboard_path if play_app?
  end

  def head_not_found_if_play_app!
    head :not_found if play_app?
  end
end
