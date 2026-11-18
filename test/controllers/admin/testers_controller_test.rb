# frozen_string_literal: true

require "test_helper"

module Admin
  class TestersControllerTest < ActionDispatch::IntegrationTest
    setup do
      @admin = users(:admin)
      @user = users(:one)
    end

    test "non admin is redirected with access denied" do
      sign_in_as @user
      get admin_testers_path

      assert_redirected_to dashboard_path
      follow_redirect!
      assert_match(/Access denied/i, flash[:alert].to_s + response.body)
    end

    test "guest is sent to sign in" do
      get admin_testers_path
      assert_redirected_to new_session_path
    end

    test "admin can open testers and mailto email" do
      travel_to Time.zone.parse("2026-11-18 12:00:00") do
        @user.update!(onboarding_completed_at: nil)
        sign_in_as @admin

        get admin_testers_path

        assert_response :success
        assert_select "#admin-testers"
        assert_select ".lp-admin-tester__name", text: @user.display_name
        assert_select "a.lp-admin-tester__email[href=?]", "mailto:#{@user.email_address}"
        assert_select ".lp-admin-tester__reason", text: I18n.t("admin.testers.reason.onboarding")
        assert_select ".lp-admin__nav-link.is-active", text: I18n.t("admin.nav.testers")
      end
    end
  end
end
