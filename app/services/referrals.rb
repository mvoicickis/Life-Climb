# frozen_string_literal: true

# One-level friend referral: capture ?r=CODE in a cookie, attach on signup or beta waitlist.
module Referrals
  COOKIE_NAME = :lp_ref
  COOKIE_TTL = 60.days

  module_function

  def remember_from_params!(params:, cookies:)
    return if cookies.signed[COOKIE_NAME].present?

    code = params[:r].to_s.strip
    return if code.blank?
    return unless User.exists?(referral_code: code)

    cookies.signed[COOKIE_NAME] = cookie_options.merge(value: code, expires: COOKIE_TTL.from_now)
  end

  def referrer_for(cookies)
    code = cookies.signed[COOKIE_NAME].to_s.strip
    return if code.blank?

    User.find_by(referral_code: code)
  end

  def attach_from_cookie!(user:, cookies:)
    attach!(user: user, referrer: referrer_for(cookies))
  end

  def attach!(user:, referrer:)
    return if user.referred_by_id.present?
    return if referrer.nil?
    return if referrer.id == user.id

    user.update!(referred_by_id: referrer.id)
  end

  def attach_to_beta_signup!(signup:, cookies:)
    referrer = referrer_for(cookies)
    return if referrer.nil?

    signup.referred_by_id = referrer.id
  end

  def cookie_options
    {
      httponly: true,
      same_site: :lax,
      secure: Rails.env.production?
    }
  end
end
