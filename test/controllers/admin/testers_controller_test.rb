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
        assert_select "#tester-#{@user.id}"
        assert_select ".lp-admin-tester__name", text: @user.display_name
        assert_select "a.lp-admin-tester__email[href=?]", "mailto:#{@user.email_address}"
        assert_select ".lp-admin-tester__reason", text: I18n.t("admin.testers.reason.onboarding")
        assert_select ".lp-admin__nav-link.is-active", text: I18n.t("admin.nav.testers")
        assert_select "a.lp-admin__btn", text: I18n.t("admin.testers.filter_needs_message")
      end
    end

    test "whatsapp details become a wa.me link" do
      travel_to Time.zone.parse("2026-11-18 12:00:00") do
        @user.update!(onboarding_completed_at: nil)
        TesterContact.create!(
          user: @user,
          channel: "whatsapp",
          details: "+00 353 87 234 6580",
          updated_by: @admin
        )
        sign_in_as @admin

        get admin_testers_path

        assert_select "#tester-#{@user.id} a.lp-admin-tester__reach-link[href=?]", "https://wa.me/353872346580"
      end
    end

    test "short whatsapp digits stay plain text" do
      travel_to Time.zone.parse("2026-11-18 12:00:00") do
        @user.update!(onboarding_completed_at: nil)
        TesterContact.create!(
          user: @user,
          channel: "whatsapp",
          details: "12345",
          updated_by: @admin
        )
        sign_in_as @admin

        get admin_testers_path

        assert_select "#tester-#{@user.id} a.lp-admin-tester__reach-link", count: 0
        assert_select "#tester-#{@user.id} .lp-admin-tester__reach-text", text: "12345"
      end
    end

    test "email channel falls back to account email mailto" do
      travel_to Time.zone.parse("2026-11-18 12:00:00") do
        @user.update!(onboarding_completed_at: nil)
        TesterContact.create!(
          user: @user,
          channel: "email",
          details: nil,
          updated_by: @admin
        )
        sign_in_as @admin

        get admin_testers_path

        assert_select "#tester-#{@user.id} a.lp-admin-tester__reach-link[href=?]", "mailto:#{@user.email_address}"
      end
    end

    test "messenger stays plain text" do
      travel_to Time.zone.parse("2026-11-18 12:00:00") do
        @user.update!(onboarding_completed_at: nil)
        TesterContact.create!(
          user: @user,
          channel: "messenger",
          details: "Luis Gómez on Messenger",
          updated_by: @admin
        )
        sign_in_as @admin

        get admin_testers_path

        assert_select "#tester-#{@user.id} a.lp-admin-tester__reach-link", count: 0
        assert_select "#tester-#{@user.id} .lp-admin-tester__reach-text", text: "Luis Gómez on Messenger"
      end
    end

    test "needs message filter hides recently contacted reason rows" do
      travel_to Time.zone.parse("2026-11-18 12:00:00") do
        @user.update!(onboarding_completed_at: nil)
        TesterContact.create!(
          user: @user,
          channel: "whatsapp",
          details: "353872346580",
          last_contacted_on: Date.current,
          note: "pinged",
          updated_by: @admin
        )
        sign_in_as @admin

        get admin_testers_path
        assert_select "#tester-#{@user.id}", count: 0

        get admin_testers_path(filter: Testers::FILTER_EVERYONE)
        assert_select "#tester-#{@user.id}"
        assert_select "#tester-#{@user.id} .lp-admin-tester__last-contact",
                      text: /Last contacted:.*pinged/
      end
    end
  end
end
