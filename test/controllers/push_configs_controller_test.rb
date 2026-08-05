# frozen_string_literal: true

require "test_helper"

class PushConfigsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
  end

  test "show returns vapid public key" do
    get push_config_path(format: :json)
    assert_response :success
    body = JSON.parse(response.body)
    assert body["publicKey"].present?
    assert_equal true, body["enabled"]
  end

  test "requires authentication" do
    sign_out
    get push_config_path(format: :json)
    assert_response :redirect
  end
end
