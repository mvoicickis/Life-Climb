# frozen_string_literal: true

require "test_helper"

class ReferralShareSurfacesTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    @referral_param = "?r=#{@user.referral_code}"
    @plain_landing = "#{CanonicalHost.base_url}/?s=lp"
  end

  test "settings invite share url includes referral code" do
    get settings_path
    assert_response :success
    assert_select "[data-share-url-value=?]", ReferralShareUrl.for(@user)
  end

  test "support invite share url includes referral code" do
    get support_path
    assert_response :success
    assert_match @referral_param, response.body
    assert_match(/data-share-url-value/, response.body)
  end

  test "invite full message includes referral landing url" do
    full = InviteShareMessage.call(landing_url: ReferralShareUrl.for(@user))
    assert_includes full, @referral_param
    assert_includes full, "s=lp"
  end

  test "user without referral code gets plain landing on invite url" do
    user = User.new(referral_code: nil)
    assert_equal @plain_landing, ReferralShareUrl.for(user)
  end
end