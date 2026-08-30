# frozen_string_literal: true

require "test_helper"

class UserPrivilegedScopeTest < ActiveSupport::TestCase
  setup do
    @previous_emails = ENV["DEVELOPER_EMAILS"]
    ENV.delete("DEVELOPER_EMAIL")
    ENV.delete("DEVELOPER_EMAILS")
  end

  teardown do
    ENV["DEVELOPER_EMAILS"] = @previous_emails
  end

  test "privileged includes admin and developer accounts" do
    admin = users(:admin)
    developer = users(:one)
    developer.update_columns(developer: true)

    ids = User.privileged.pluck(:id)
    assert_includes ids, admin.id
    assert_includes ids, developer.id
    refute_includes ids, users(:two).id
  end

  test "excluding_privileged omits env whitelisted developer emails" do
    users(:one).update_columns(developer: false)
    ENV["DEVELOPER_EMAILS"] = users(:one).email_address

    refute_includes User.excluding_privileged.pluck(:id), users(:one).id
    assert_includes User.privileged.pluck(:id), users(:one).id
  end
end
