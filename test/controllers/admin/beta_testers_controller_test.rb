# frozen_string_literal: true

require "test_helper"

module Admin
  class BetaTestersControllerTest < ActionDispatch::IntegrationTest
    setup do
      @admin = users(:admin)
      @user = users(:one)
      BetaTester.delete_all
    end

    test "non admin is redirected with access denied" do
      sign_in_as @user
      get admin_beta_testers_path

      assert_redirected_to dashboard_path
      follow_redirect!
      assert_match(/Access denied/i, flash[:alert].to_s + response.body)
    end

    test "guest is sent to sign in" do
      get admin_beta_testers_path
      assert_redirected_to new_session_path
    end

    test "admin page shows weekly cards and funnel" do
      sign_in_as @admin

      get admin_beta_testers_path

      assert_response :success
      assert_select "h2", text: I18n.t("admin.beta_testers.stats.karen_title")
      assert_select "h2", text: I18n.t("admin.beta_testers.stats.mareks_title")
      assert_select "h2", text: I18n.t("admin.beta_testers.funnel.title")
      assert_includes response.body, I18n.t("admin.beta_testers.funnel.android_signed_up")
    end

    test "admin paste shows import summary" do
      sign_in_as @admin
      BetaTester.create!(email: "old@example.com", added_at: Time.current)

      post admin_beta_testers_path, params: { emails: "old@example.com, new@example.com, not-an-email" }

      assert_redirected_to admin_beta_testers_path
      assert_equal I18n.t(
        "admin.beta_testers.import_summary",
        added: 1,
        already_there: 1,
        no_account: 2,
        invalid: 1
      ), flash[:notice]
    end

    test "invite sets beta_invited_at and undo clears it" do
      travel_to Time.zone.parse("2026-11-23 10:00:00") do
        sign_in_as @admin
        @user.update!(beta_invited_at: nil)

        patch admin_beta_tester_invite_path(user_id: @user.id)
        assert_redirected_to admin_beta_testers_path
        assert @user.reload.beta_invited_at.present?

        patch admin_beta_tester_uninvite_path(user_id: @user.id)
        assert_redirected_to admin_beta_testers_path
        assert_nil @user.reload.beta_invited_at
      end
    end
  end
end
