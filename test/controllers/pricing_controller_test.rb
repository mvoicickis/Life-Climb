# frozen_string_literal: true

require "test_helper"

class PricingControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "requires authentication" do
    sign_out
    get pricing_path
    assert_redirected_to new_session_path
  end

  test "shows pricing page for signed-in user" do
    get pricing_path
    assert_response :success
    assert_select "h1", text: I18n.t("pricing.title")
  end

  test "shows success notice without writing subscription fields" do
    @user.update_columns(
      stripe_subscription_id: nil,
      subscription_status: nil,
      current_period_end: nil
    )

    get pricing_path(billing: "success")
    assert_response :success
    assert_match I18n.t("pricing.checkout_success"), response.body

    @user.reload
    assert_nil @user.stripe_subscription_id
    assert_nil @user.subscription_status
    assert_nil @user.current_period_end
  end
end
