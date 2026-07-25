require "test_helper"

class SecurityHardeningTest < ActionDispatch::IntegrationTest
  test "password must be at least 12 characters" do
    user = User.new(
      email_address: "secure@example.com",
      password: "short",
      password_confirmation: "short"
    )
    assert_not user.valid?
    assert_includes user.errors[:password].join, "too short"
  end

  test "email must look like an email" do
    user = User.new(
      email_address: "not-an-email",
      password: "password12345",
      password_confirmation: "password12345"
    )
    assert_not user.valid?
  end

  test "support dismiss rejects arbitrary milestone keys" do
    sign_in_as users(:one)
    before = users(:one).reload.support_milestones_shown
    post dismiss_support_moment_path, params: { milestone: "evil_key_" + ("x" * 500) }
    assert_equal before, users(:one).reload.support_milestones_shown
  end

  test "rack attack is loaded" do
    assert defined?(Rack::Attack)
  end
end
