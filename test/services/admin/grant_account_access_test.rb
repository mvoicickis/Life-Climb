# frozen_string_literal: true

require "test_helper"

module Admin
  class GrantAccountAccessTest < ActiveSupport::TestCase
    test "grants admin and developer only for the target email" do
      target = User.create!(
        email_address: "karenchi.s.c@gmail.com",
        password: "password12345",
        password_confirmation: "password12345",
        name: "Karen",
        home_stat_count: 6,
        admin: false,
        developer: false
      )
      other = users(:one)
      other_admin_before = other.admin?
      other_developer_before = other.read_attribute(:developer)

      results = Admin::GrantAccountAccess.ensure_all!
      result = results.find { |r| r[:email] == "karenchi.s.c@gmail.com" }

      assert result[:ok]
      assert result[:changed]
      assert target.reload.admin?
      assert_equal true, target.read_attribute(:developer)
      assert target.developer?

      assert_equal other_admin_before, other.reload.admin?
      assert_equal other_developer_before, other.read_attribute(:developer)
    end

    test "is idempotent and reports not found when missing" do
      missing = Admin::GrantAccountAccess.new(
        email: "nobody-here@example.com",
        admin: true,
        developer: true
      ).ensure!

      assert_not missing[:ok]
      assert_equal "user_not_found", missing[:reason]

      target = User.create!(
        email_address: "karenchi.s.c@gmail.com",
        password: "password12345",
        password_confirmation: "password12345",
        name: "Karen",
        home_stat_count: 6,
        admin: true,
        developer: true
      )

      again = Admin::GrantAccountAccess.new(
        email: target.email_address,
        admin: true,
        developer: true
      ).ensure!

      assert again[:ok]
      assert_not again[:changed]
      assert again[:admin]
      assert again[:developer]
    end
  end
end
