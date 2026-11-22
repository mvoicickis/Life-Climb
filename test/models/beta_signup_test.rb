# frozen_string_literal: true

require "test_helper"

class BetaSignupTest < ActiveSupport::TestCase
  test "requires email" do
    signup = BetaSignup.new(email: "")

    assert_not signup.valid?
    assert_includes signup.errors[:email], "can't be blank"
  end

  test "rejects invalid email format" do
    signup = BetaSignup.new(email: "not-an-email")

    assert_not signup.valid?
    assert signup.errors[:email].any?
  end

  test "normalizes email to lowercase stripped" do
    signup = BetaSignup.create!(email: "  Alex@Example.COM ")

    assert_equal "alex@example.com", signup.email
  end

  test "email must be unique" do
    BetaSignup.create!(email: "join@example.com")
    duplicate = BetaSignup.new(email: "JOIN@example.com")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:email], "has already been taken"
  end

  test "classifies android from user agent" do
    signup = BetaSignup.create!(
      email: "android@example.com",
      user_agent: "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36"
    )

    assert_equal "android", signup.device
  end

  test "classifies iphone from user agent" do
    signup = BetaSignup.create!(
      email: "iphone@example.com",
      user_agent: "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)"
    )

    assert_equal "iphone", signup.device
  end

  test "classifies computer from user agent" do
    signup = BetaSignup.create!(
      email: "desk@example.com",
      user_agent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"
    )

    assert_equal "computer", signup.device
  end

  test "keeps an explicit device" do
    signup = BetaSignup.create!(
      email: "forced@example.com",
      device: "computer",
      user_agent: "Mozilla/5.0 (Linux; Android 14)"
    )

    assert_equal "computer", signup.device
  end
end
