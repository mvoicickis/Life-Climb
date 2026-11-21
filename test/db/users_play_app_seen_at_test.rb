# frozen_string_literal: true

require "test_helper"

class UsersPlayAppSeenAtTest < ActiveSupport::TestCase
  test "users table includes play_app_seen_at" do
    assert_includes User.column_names, "play_app_seen_at"
  end
end
