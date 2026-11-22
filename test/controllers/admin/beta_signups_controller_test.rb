# frozen_string_literal: true

require "test_helper"

module Admin
  class BetaSignupsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @admin = users(:admin)
      @user = users(:one)
    end

    test "non admin is redirected with access denied" do
      sign_in_as @user
      get admin_beta_signups_path

      assert_redirected_to dashboard_path
      follow_redirect!
      assert_match(/Access denied/i, flash[:alert].to_s + response.body)
    end

    test "guest is sent to sign in" do
      get admin_beta_signups_path
      assert_redirected_to new_session_path
    end

    test "admin lists signups newest first with count and nav" do
      travel_to Time.zone.parse("2026-11-22 12:00:00") do
        sign_in_as @admin
        BetaSignup.create!(email: "older@example.com", device: "android", source_path: "/",
                           created_at: 2.days.ago)
        BetaSignup.create!(email: "newer@example.com", device: "iphone", source_path: "/blog",
                           created_at: 1.hour.ago)

        get admin_beta_signups_path

        assert_response :success
        assert_select ".lp-admin__nav-link.is-active", text: I18n.t("admin.nav.beta_emails")
        assert_includes response.body, I18n.t("admin.beta_signups.count", count: 2)
        assert response.body.index("newer@example.com") < response.body.index("older@example.com")
      end
    end

    test "android filter limits rows" do
      sign_in_as @admin
      BetaSignup.create!(email: "android@example.com", device: "android")
      BetaSignup.create!(email: "iphone@example.com", device: "iphone")

      get admin_beta_signups_path(filter: BetaSignupsController::FILTER_ANDROID)

      assert_response :success
      assert_includes response.body, "android@example.com"
      assert_not_includes response.body, "iphone@example.com"
      assert_includes response.body, I18n.t("admin.beta_signups.count", count: 1)
    end

    test "destroy removes signup" do
      sign_in_as @admin
      signup = BetaSignup.create!(email: "gone@example.com", device: "android")

      assert_difference "BetaSignup.count", -1 do
        delete admin_beta_signup_path(signup)
      end

      assert_redirected_to admin_beta_signups_path(filter: BetaSignupsController::FILTER_ALL)
      assert_equal I18n.t("admin.beta_signups.deleted"), flash[:notice]
    end

    test "csv export includes filtered emails" do
      sign_in_as @admin
      BetaSignup.create!(email: "csv-android@example.com", device: "android", source_path: "/")
      BetaSignup.create!(email: "csv-iphone@example.com", device: "iphone", source_path: "/blog")

      get admin_beta_signups_path(format: :csv, filter: BetaSignupsController::FILTER_ANDROID)

      assert_response :success
      assert_includes response.body, "csv-android@example.com"
      assert_not_includes response.body, "csv-iphone@example.com"
      assert_match(/text\/csv/, response.media_type)
    end
  end
end