# frozen_string_literal: true

require "test_helper"

class ReferralShareUrlTest < ActiveSupport::TestCase
  test "includes referral code and share scrape param" do
    user = users(:one)
    url = ReferralShareUrl.for(user)

    assert_includes url, "?r=#{user.referral_code}"
    assert_includes url, "s=lp"
    assert_match %r{\Ahttps?://}, url
  end

  test "falls back to plain landing when user has no code" do
    user = User.new(referral_code: nil)

    assert_equal "#{CanonicalHost.base_url}/?s=lp", ReferralShareUrl.for(user)
    assert_equal "#{CanonicalHost.base_url}/?s=lp", ReferralShareUrl.for(nil)
  end

  test "url-encodes referral code" do
    user = users(:one)
    user.referral_code = "a+b/c"
    url = ReferralShareUrl.for(user)

    assert_includes url, "?r=a%2Bb%2Fc"
  end
end
