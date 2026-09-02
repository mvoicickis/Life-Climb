# frozen_string_literal: true

require "test_helper"

class UserPushOfferTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @user.update!(
      push_offer_dismiss_count: 0,
      push_offer_dismissed_at: nil,
      push_offer_permission_denied_at: nil
    )
    @user.push_subscriptions.delete_all
  end

  test "eligible on wins 1 through 3" do
    assert @user.push_offer_eligible?(win_number: 1)
    assert @user.push_offer_eligible?(win_number: 2)
    assert @user.push_offer_eligible?(win_number: 3)
    refute @user.push_offer_eligible?(win_number: 4)
  end

  test "not eligible with existing subscription" do
    PushSubscription.create!(
      user: @user,
      endpoint: "https://push.example/push-offer-test",
      p256dh: "BNcRdreALRFXTkOOUHK1EtK2wtaz5Ry4YfYCA_0QTsHJQDSiUC_nNAw0QQxmlYjXz12WA0NedmzVoY_o0U0K2pU",
      auth: "tBHItJI5svbpez7KI4CCXg"
    )

    refute @user.push_offer_eligible?(win_number: 1)
  end

  test "soft dismiss allows later wins until max asks" do
    @user.mark_push_offer_dismissed!
    assert_equal 1, @user.reload.push_offer_dismiss_count
    assert @user.push_offer_eligible?(win_number: 2)

    @user.mark_push_offer_dismissed!
    assert_equal 2, @user.reload.push_offer_dismiss_count
    assert @user.push_offer_eligible?(win_number: 3)

    @user.mark_push_offer_dismissed!
    assert_equal 3, @user.reload.push_offer_dismiss_count
    refute @user.push_offer_eligible?(win_number: 4)
  end

  test "permission denied is permanent" do
    @user.mark_push_offer_permission_denied!
    refute @user.push_offer_eligible?(win_number: 1)
    refute @user.push_offer_eligible?(win_number: 2)
  end
end
