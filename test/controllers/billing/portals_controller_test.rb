# frozen_string_literal: true

require "test_helper"

module Billing
  class PortalsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      sign_in_as(@user)
    end

    test "requires authentication" do
      sign_out
      post billing_portal_path, as: :json
      assert_redirected_to new_session_path
    end

    test "rejects missing stripe customer" do
      @user.update_columns(stripe_customer_id: nil)
      post billing_portal_path, as: :json
      assert_response :unprocessable_entity
      assert_equal "missing_customer", JSON.parse(response.body)["error"]
    end

    test "returns portal url from service" do
      @user.update_columns(stripe_customer_id: "cus_existing")
      with_singleton_stubs(
        Billing::CreatePortalSession => {
          call: ->(**) { { url: "https://billing.stripe.test/portal" } }
        }
      ) do
        post billing_portal_path, as: :json
      end

      assert_response :success
      body = JSON.parse(response.body)
      assert_equal "https://billing.stripe.test/portal", body["url"]
    end
  end
end
