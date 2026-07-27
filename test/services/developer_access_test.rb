# frozen_string_literal: true

require "test_helper"

class DeveloperAccessTest < ActiveSupport::TestCase
  setup do
    @previous_email = ENV["DEVELOPER_EMAIL"]
    @previous_emails = ENV["DEVELOPER_EMAILS"]
    ENV.delete("DEVELOPER_EMAIL")
    ENV.delete("DEVELOPER_EMAILS")
  end

  teardown do
    ENV["DEVELOPER_EMAIL"] = @previous_email
    ENV["DEVELOPER_EMAILS"] = @previous_emails
  end

  test "developer flag grants access" do
    user = users(:one)
    user.update_columns(developer: true)
    assert user.developer?
    assert DeveloperAccess.allowed?(user)
  end

  test "env whitelist grants access without db flag" do
    user = users(:one)
    user.update_columns(developer: false)
    ENV["DEVELOPER_EMAILS"] = "one@example.com,other@example.com"

    assert user.developer?
    assert DeveloperAccess.email_allowed?("one@example.com")
    refute DeveloperAccess.email_allowed?("two@example.com")
  end

  test "normal users are not developers" do
    user = users(:one)
    user.update_columns(developer: false)
    refute user.developer?
  end
end
