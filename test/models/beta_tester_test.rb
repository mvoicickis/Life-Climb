# frozen_string_literal: true

require "test_helper"

class BetaTesterTest < ActiveSupport::TestCase
  test "normalizes email to lowercase stripped" do
    beta_tester = BetaTester.create!(email: "  Alex@Example.COM ", added_at: Time.current)

    assert_equal "alex@example.com", beta_tester.email
  end

  test "email must be unique case insensitively" do
    BetaTester.create!(email: "join@example.com", added_at: Time.current)
    duplicate = BetaTester.new(email: "JOIN@example.com", added_at: Time.current)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:email], "has already been taken"
  end

  test "user is optional" do
    beta_tester = BetaTester.create!(email: "solo@example.com", added_at: Time.current, user: nil)

    assert_predicate beta_tester, :valid?
    assert_nil beta_tester.user
  end
end
