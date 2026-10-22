# frozen_string_literal: true

require "test_helper"

class SessionCspFormActionTest < ActionDispatch::IntegrationTest
  test "sign in page allows Google OAuth in form-action CSP" do
    get new_session_path

    assert_response :success
    policy = response.headers["Content-Security-Policy"].to_s
    assert_includes policy, "form-action"
    assert_includes policy, "https://accounts.google.com"
  end
end
