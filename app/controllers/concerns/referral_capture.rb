# frozen_string_literal: true

module ReferralCapture
  extend ActiveSupport::Concern

  included do
    before_action :remember_referral_from_params
  end

  private

  def remember_referral_from_params
    Referrals.remember_from_params!(params: params, cookies: cookies)
  end
end