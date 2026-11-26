# frozen_string_literal: true

# Absolute landing URL for product shares (?s=lp) with optional one-level referral (?r=CODE).
class ReferralShareUrl
  SHARE_PATH = "/?s=lp"

  def self.for(user, base_url: CanonicalHost.base_url)
    new(user, base_url: base_url).call
  end

  def initialize(user, base_url: CanonicalHost.base_url)
    @user = user
    @base_url = base_url.to_s.chomp("/")
  end

  def call
    return "#{@base_url}#{SHARE_PATH}" if @user.blank? || @user.referral_code.blank?

    code = ERB::Util.url_encode(@user.referral_code.to_s)
    "#{@base_url}/?r=#{code}&s=lp"
  end
end
