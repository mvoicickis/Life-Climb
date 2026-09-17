# frozen_string_literal: true

require "test_helper"

class UserPushOfferTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @user.update!(
      push_offer_dismiss_count: 0,
      push_offer_dismissed_at: nil,
      push_offer_permission_denied_at: nil,
      push_offer_last_shown_on: nil
    )
    @user.push_subscriptions.delete_all
    @user.notification_preference&.destroy
  end

  test "eligible on win 5 without subscription" do
    assert @user.push_offer_eligible?(win_number: 5)
    assert @user.push_offer_eligible?
  end

  test "not eligible when endpoint matches stored subscription" do
    endpoint = "https://push.example/push-offer-test"
    PushSubscription.create!(
      user: @user,
      endpoint: endpoint,
      p256dh: "BNcRdreALRFXTkOOUHK1EtK2wtaz5Ry4YfYCA_0QTsHJQDSiUC_nNAw0QQxmlYjXz12WA0NedmzVoY_o0U0K2pU",
      auth: "tBHItJI5svbpez7KI4CCXg"
    )

    refute @user.push_offer_eligible?(endpoint: endpoint)
  end

  test "eligible when another device has a subscription but endpoint not sent" do
    PushSubscription.create!(
      user: @user,
      endpoint: "https://push.example/other-device",
      p256dh: "BNcRdreALRFXTkOOUHK1EtK2wtaz5Ry4YfYCA_0QTsHJQDSiUC_nNAw0QQxmlYjXz12WA0NedmzVoY_o0U0K2pU",
      auth: "tBHItJI5svbpez7KI4CCXg"
    )

    assert @user.push_offer_eligible?
  end

  test "eligible when another device has a subscription but this endpoint is different" do
    PushSubscription.create!(
      user: @user,
      endpoint: "https://push.example/browser-tab",
      p256dh: "BNcRdreALRFXTkOOUHK1EtK2wtaz5Ry4YfYCA_0QTsHJQDSiUC_nNAw0QQxmlYjXz12WA0NedmzVoY_o0U0K2pU",
      auth: "tBHItJI5svbpez7KI4CCXg"
    )

    assert @user.push_offer_eligible?(endpoint: "https://push.example/installed-app")
  end

  test "not eligible after shown today" do
    travel_to Time.zone.local(2026, 8, 6, 12, 0, 0) do
      @user.mark_push_offer_shown!
      assert_equal Date.new(2026, 8, 6), @user.reload.push_offer_last_shown_on
      refute @user.push_offer_eligible?(win_number: 5)
    end
  end

  test "eligible again next local day" do
    @user.create_notification_preference!(time_zone: "Europe/Berlin")
    travel_to Time.find_zone!("Europe/Berlin").local(2026, 8, 6, 20, 0, 0) do
      @user.mark_push_offer_shown!
    end

    travel_to Time.find_zone!("Europe/Berlin").local(2026, 8, 7, 8, 0, 0) do
      assert @user.reload.push_offer_eligible?(win_number: 5)
    end
  end

  test "soft dismiss allows until max asks" do
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
    refute @user.push_offer_eligible?(win_number: 5)
  end
end
