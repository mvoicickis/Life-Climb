# frozen_string_literal: true

require "test_helper"

module Billing
  class CheckoutsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      sign_in_as(@user)
    end

    test "requires authentication" do
      sign_out
      post billing_checkout_path, params: { interval: "monthly" }, as: :json
      assert_redirected_to new_session_path
    end

    test "rejects invalid interval" do
      post billing_checkout_path, params: { interval: "weekly" }, as: :json
      assert_response :unprocessable_entity
      assert_equal "invalid_interval", JSON.parse(response.body)["error"]
    end

    test "returns checkout url from service" do
      with_singleton_stubs(
        Billing::CreateCheckoutSession => {
          call: ->(**) { { url: "https://checkout.stripe.test/session" } }
        }
      ) do
        post billing_checkout_path, params: { interval: "monthly" }, as: :json
      end

      assert_response :success
      body = JSON.parse(response.body)
      assert_equal "https://checkout.stripe.test/session", body["url"]
    end
  end
end
