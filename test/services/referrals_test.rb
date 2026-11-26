# frozen_string_literal: true

require "test_helper"

class ReferralsTest < ActiveSupport::TestCase
  test "attach! sets referred_by once and skips self-referral" do
    referrer = users(:one)
    invitee = User.create!(
      name: "Invitee",
      email_address: "invitee-#{SecureRandom.hex(4)}@example.com",
      password: "password12345"
    )

    Referrals.attach!(user: invitee, referrer: referrer)
    assert_equal referrer.id, invitee.reload.referred_by_id

    other = users(:two)
    Referrals.attach!(user: invitee, referrer: other)
    assert_equal referrer.id, invitee.referred_by_id

    Referrals.attach!(user: referrer, referrer: referrer)
    assert_nil referrer.reload.referred_by_id
  end

  test "every user has a unique referral code" do
    codes = User.pluck(:referral_code)
    assert_equal codes.uniq.size, codes.size
    codes.each { |code| assert code.present? }
  end
end