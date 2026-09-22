# frozen_string_literal: true

require "test_helper"

class OfflinePageCacheLogoutTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "sign out form clears offline page cache before submit" do
    get settings_path
    assert_response :success
    assert_match(/submit->offline-page-cache#clearBeforeSignOut/, response.body)
  end
end
