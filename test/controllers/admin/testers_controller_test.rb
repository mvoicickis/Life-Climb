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
        assert_select ".lp-admin-tester__push.is-off",
                      text: I18n.t("admin.testers.push_label", status: I18n.t("admin.testers.push_status.off"))
        assert_select ".lp-admin__nav-link.is-active", text: I18n.t("admin.nav.testers")
        assert_select "a.lp-admin__btn", text: I18n.t("admin.testers.filter_needs_message")
        assert_select "a.lp-admin-testers__play-link[href=?][target=_blank][rel=noopener]",
                      Testers::PLAY_TESTERS_URL,
                      text: I18n.t("admin.testers.play_testers_list")
      end
    end

    test "tester card shows push broken label and reason" do
      travel_to Time.zone.parse("2026-11-18 12:00:00") do
        @user.update!(onboarding_completed_at: 2.weeks.ago)
        seed_climb!(@user, today_mission: "Push check")
        @user.strategy_goals.battles.order(:id).last.update!(completed_at: 1.day.ago, repeat: nil)
        PushSubscription.create!(
          user: @user,
          endpoint: "https://push.example/card-#{@user.id}",
          p256dh: "p256dh-key",
          auth: "auth-key",
          last_error_at: 1.hour.ago,
          last_error: "StandardError: boom"
        )
        sign_in_as @admin

        get admin_testers_path

        assert_select "#tester-#{@user.id} .lp-admin-tester__push.is-broken",
                      text: I18n.t("admin.testers.push_label", status: I18n.t("admin.testers.push_status.broken"))
        assert_select "#tester-#{@user.id} .lp-admin-tester__reason",
                      text: I18n.t("admin.testers.reason.push_broken")
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

    test "admin sees today box and climbers calendar" do
      zone = Testers::DAY_ZONE
      travel_to Time.find_zone!(zone).local(2026, 11, 18, 12, 0, 0) do
        seed_climb!(@user, today_mission: "Today climb")
        battle = @user.strategy_goals.battles.order(:id).last
        battle.update!(
          completed_at: Time.find_zone!(zone).local(2026, 11, 18, 9, 0, 0),
          repeat: nil
        )
        sign_in_as @admin

        get admin_testers_path

        assert_response :success
        assert_select "#admin-climbers-today.is-goal-partial"
        assert_select "#admin-climbers-today .lp-admin-climbers__today-count",
                      text: /1 \/ 12 climbed today/
        assert_select "turbo-frame#climbers_calendar"
        assert_select "#admin-climbers-goal-met", text: /Goal met on 0 days this month/
        assert_select ".lp-admin-climbers-cal__cell.is-today .lp-admin-climbers-cal__dot", text: "1"
      end
    end

    test "today box turns green at the goal and shows admin extras" do
      zone = Testers::DAY_ZONE
      travel_to Time.find_zone!(zone).local(2026, 11, 18, 12, 0, 0) do
        Testers::DAILY_CLIMBERS_GOAL.times do |index|
          climber = User.create!(
            email_address: "goal-#{index}-#{SecureRandom.hex(3)}@example.com",
            name: "Goal #{index}",
            password: "password12345",
            password_confirmation: "password12345",
            onboarding_completed_at: 1.week.ago
          )
          seed_climb!(climber, today_mission: "Goal battle #{index}")
          climber.strategy_goals.battles.order(:id).last.update!(
            completed_at: Time.find_zone!(zone).local(2026, 11, 18, 10, 0, 0),
            repeat: nil
          )
        end
        seed_climb!(@admin, today_mission: "Admin climb")
        @admin.strategy_goals.battles.order(:id).last.update!(
          completed_at: Time.find_zone!(zone).local(2026, 11, 18, 11, 0, 0),
          repeat: nil
        )
        sign_in_as @admin

        get admin_testers_path

        assert_select "#admin-climbers-today.is-goal-met"
        assert_select "#admin-climbers-today .lp-admin-climbers__today-count",
                      text: /12 \/ 12 climbed today/
        assert_select "#admin-climbers-today .lp-admin-climbers__today-admins", text: /\+1 admin/
        assert_select "#admin-climbers-goal-met", text: /Goal met on 1 day this month/
      end
    end

    test "month nav stays inside climbers frame and blocks future months" do
      zone = Testers::DAY_ZONE
      travel_to Time.find_zone!(zone).local(2026, 11, 18, 12, 0, 0) do
        sign_in_as @admin

        get admin_testers_path(climbers_month: "2026-10")
        assert_response :success
        assert_select "#admin-climbers-cal-title", text: /October 2026/
        assert_select "a.lp-stats-cal__nav[href*=?]", "climbers_month=2026-11"

        get admin_testers_path(climbers_month: "2026-12")
        assert_response :success
        assert_select "#admin-climbers-cal-title", text: /November 2026/
        assert_select "a.lp-stats-cal__nav[aria-label=?]", I18n.t("admin.testers.climbers_next"), count: 0

        get admin_testers_path(climbers_month: "2026-10"),
            headers: { "Turbo-Frame" => "climbers_calendar" }
        assert_response :success
        assert_select "turbo-frame#climbers_calendar"
        assert_select "#admin-climbers-today", count: 0
        assert_select "#admin-testers", count: 0
      end
    end

    test "non admin cannot see climbers tracker" do
      sign_in_as @user
      get admin_testers_path

      assert_redirected_to dashboard_path
      follow_redirect!
      assert_select "#admin-climbers-today", count: 0
      assert_select "turbo-frame#climbers_calendar", count: 0
    end

    test "tester card shows device line and android goal copy" do
      zone = Testers::DAY_ZONE
      travel_to Time.find_zone!(zone).local(2026, 11, 18, 12, 0, 0) do
        android_ua =
          "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) " \
          "Chrome/120.0.0.0 Mobile Safari/537.36"
        @user.update!(onboarding_completed_at: nil, play_app_seen_at: 1.day.ago)
        @user.sessions.create!(user_agent: android_ua, ip_address: "127.0.0.1")
        seed_climb!(@user, today_mission: "Android climb")
        @user.strategy_goals.battles.order(:id).last.update!(
          completed_at: Time.find_zone!(zone).local(2026, 11, 18, 9, 0, 0),
          repeat: nil
        )
        sign_in_as @admin

        get admin_testers_path(filter: Testers::FILTER_EVERYONE)

        assert_select ".lp-admin-climbers__today-android", text: /Android climbed today: 1 \/ 12/
        assert_select "#tester-#{@user.id} .lp-admin-tester__device",
                      text: /🤖 Android.*Play app/
        assert_select "a[href*='device=android']",
                      text: I18n.t("admin.testers.device_filter.android")
      end
    end

    test "android device filter hides non android testers" do
      travel_to Time.zone.parse("2026-11-18 12:00:00") do
        android_ua =
          "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) " \
          "Chrome/120.0.0.0 Mobile Safari/537.36"
        iphone_ua =
          "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) " \
          "Version/17.0 Mobile/15E148 Safari/604.1"
        @user.update!(onboarding_completed_at: nil)
        users(:two).update!(onboarding_completed_at: nil)
        @user.sessions.create!(user_agent: android_ua, ip_address: "127.0.0.1")
        users(:two).sessions.create!(user_agent: iphone_ua, ip_address: "127.0.0.1")
        sign_in_as @admin

        get admin_testers_path(filter: Testers::FILTER_EVERYONE, device: Testers::DEVICE_FILTER_ANDROID)

        assert_select "#tester-#{@user.id}"
        assert_select "#tester-#{users(:two).id}", count: 0
      end
    end
  end
end
