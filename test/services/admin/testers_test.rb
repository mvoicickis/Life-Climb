# frozen_string_literal: true

require "test_helper"

module Admin
  class TestersTest < ActiveSupport::TestCase
    setup do
      @admin = users(:admin)
      @user = users(:one)
      @other = users(:two)
      ClimbPartnership.delete_all
      PushSubscription.delete_all
      TesterContact.delete_all
    end

    test "excludes admin and developer accounts" do
      rows = Testers.call(filter: Testers::FILTER_EVERYONE)
      ids = rows.map { |row| row.user.id }

      assert_includes ids, @user.id
      assert_not_includes ids, @admin.id
    end

    test "reason is onboarding when onboarding is incomplete" do
      travel_to Time.zone.parse("2026-11-18 12:00:00") do
        @user.update!(onboarding_completed_at: nil)

        row = row_for(@user)
        assert_equal :onboarding, row.reason_key
        assert_equal I18n.t("admin.testers.reason.onboarding"), row.reason
      end
    end

    test "reason is never won when onboarded with no battles" do
      travel_to Time.zone.parse("2026-11-18 12:00:00") do
        @user.update!(onboarding_completed_at: 2.weeks.ago)
        @user.strategy_goals.battles.update_all(completed_at: nil)
        @user.daily_todos.update_all(completed_at: nil)

        row = row_for(@user)
        assert_equal :never_won, row.reason_key
        assert_equal I18n.t("admin.testers.reason.never_won"), row.reason
      end
    end

    test "reason is stale when last win was 4 days ago" do
      travel_to Time.zone.parse("2026-11-18 12:00:00") do
        @user.update!(onboarding_completed_at: 2.weeks.ago)
        plant_one_shot_win!(@user, completed_at: 4.days.ago)

        row = row_for(@user)
        assert_equal :stale, row.reason_key
        assert_equal I18n.t("admin.testers.reason.stale", count: 4), row.reason
        assert_equal 4, row.days_since_last_win
      end
    end

    test "no reason when won yesterday and push is healthy or off" do
      travel_to Time.zone.parse("2026-11-18 12:00:00") do
        @user.update!(onboarding_completed_at: 2.weeks.ago)
        plant_one_shot_win!(@user, completed_at: 1.day.ago)

        row = row_for(@user)
        assert_nil row.reason_key
        assert_nil row.reason
        assert_equal :off, row.push_status
      end
    end

    test "push status ok when recent success and no newer error" do
      travel_to Time.zone.parse("2026-11-18 12:00:00") do
        @user.update!(onboarding_completed_at: 2.weeks.ago)
        plant_one_shot_win!(@user, completed_at: 1.day.ago)
        PushSubscription.create!(
          user: @user,
          endpoint: "https://push.example/ok-#{@user.id}",
          p256dh: "p256dh-key",
          auth: "auth-key",
          last_success_at: 2.days.ago,
          last_error_at: 5.days.ago,
          last_error: "StandardError: old"
        )

        row = row_for(@user)
        assert_equal :ok, row.push_status
        assert_nil row.reason_key
      end
    end

    test "push status broken when latest is an error" do
      travel_to Time.zone.parse("2026-11-18 12:00:00") do
        @user.update!(onboarding_completed_at: 2.weeks.ago)
        plant_one_shot_win!(@user, completed_at: 1.day.ago)
        PushSubscription.create!(
          user: @user,
          endpoint: "https://push.example/err-#{@user.id}",
          p256dh: "p256dh-key",
          auth: "auth-key",
          last_success_at: 2.days.ago,
          last_error_at: 1.hour.ago,
          last_error: "StandardError: boom"
        )

        row = row_for(@user)
        assert_equal :broken, row.push_status
        assert_equal :push_broken, row.reason_key
        assert_equal I18n.t("admin.testers.reason.push_broken"), row.reason
      end
    end

    test "push status broken when no success in 7 days" do
      travel_to Time.zone.parse("2026-11-18 12:00:00") do
        @user.update!(onboarding_completed_at: 2.weeks.ago)
        plant_one_shot_win!(@user, completed_at: 1.day.ago)
        PushSubscription.create!(
          user: @user,
          endpoint: "https://push.example/stale-#{@user.id}",
          p256dh: "p256dh-key",
          auth: "auth-key",
          last_success_at: 10.days.ago
        )

        row = row_for(@user)
        assert_equal :broken, row.push_status
        assert_equal :push_broken, row.reason_key
      end
    end

    test "push status off when no subscriptions" do
      travel_to Time.zone.parse("2026-11-18 12:00:00") do
        @user.update!(onboarding_completed_at: 2.weeks.ago)
        plant_one_shot_win!(@user, completed_at: 1.day.ago)

        row = row_for(@user)
        assert_equal :off, row.push_status
        assert_nil row.reason_key
      end
    end

    test "needs message filter includes push broken" do
      travel_to Time.zone.parse("2026-11-18 12:00:00") do
        @user.update!(onboarding_completed_at: 2.weeks.ago, name: "Push broken user")
        plant_one_shot_win!(@user, completed_at: 1.day.ago)
        PushSubscription.create!(
          user: @user,
          endpoint: "https://push.example/needs-#{@user.id}",
          p256dh: "p256dh-key",
          auth: "auth-key",
          last_error_at: 1.hour.ago,
          last_error: "StandardError: boom"
        )

        needs = Testers.call(filter: Testers::FILTER_NEEDS_MESSAGE).map { |row| row.user.name }
        assert_includes needs, "Push broken user"
      end
    end

    test "sorts reason rows first then by last win" do
      travel_to Time.zone.parse("2026-11-18 12:00:00") do
        @user.update!(onboarding_completed_at: nil, name: "Needs onboarding")
        @other.update!(onboarding_completed_at: 2.weeks.ago, name: "Fresh win")
        plant_one_shot_win!(@other, completed_at: 1.day.ago)

        stale = User.create!(
          email_address: "stale-tester-#{SecureRandom.hex(4)}@example.com",
          name: "Stale win",
          password: "password12345",
          password_confirmation: "password12345",
          onboarding_completed_at: 2.weeks.ago
        )
        plant_one_shot_win!(stale, completed_at: 5.days.ago)

        User.create!(
          email_address: "never-tester-#{SecureRandom.hex(4)}@example.com",
          name: "Never won",
          password: "password12345",
          password_confirmation: "password12345",
          onboarding_completed_at: 2.weeks.ago
        )

        rows = Testers.call(filter: Testers::FILTER_EVERYONE)
        names = rows.map { |row| row.user.name }
        assert_operator names.index("Needs onboarding"), :<, names.index("Never won")
        assert_operator names.index("Never won"), :<, names.index("Stale win")
        assert_operator names.index("Stale win"), :<, names.index("Fresh win")
      end
    end

    test "marks push and partner from batched lookups" do
      travel_to Time.zone.parse("2026-11-18 12:00:00") do
        @user.update!(onboarding_completed_at: 2.weeks.ago)
        plant_one_shot_win!(@user, completed_at: 1.day.ago)
        seed_climb!(@other, area_key: "self", today_mission: "Partner day")
        PushSubscription.create!(
          user: @user,
          endpoint: "https://push.example/testers-#{@user.id}",
          p256dh: "p256dh-key",
          auth: "auth-key",
          last_success_at: 1.day.ago
        )
        invite = ClimbTogether::Invite.call(user: @user)
        ClimbTogether::Accept.call(user: @other, token: invite.token)

        row = row_for(@user)
        assert_equal :ok, row.push_status
        assert row.partner
      end
    end

    test "needs message filter keeps reason rows not contacted recently" do
      travel_to Time.zone.parse("2026-11-18 12:00:00") do
        @user.update!(onboarding_completed_at: nil, name: "Needs ping")
        @other.update!(onboarding_completed_at: 2.weeks.ago, name: "Fresh win")
        plant_one_shot_win!(@other, completed_at: 1.day.ago)

        contacted = User.create!(
          email_address: "contacted-tester-#{SecureRandom.hex(4)}@example.com",
          name: "Contacted today",
          password: "password12345",
          password_confirmation: "password12345",
          onboarding_completed_at: nil
        )
        TesterContact.create!(
          user: contacted,
          channel: "email",
          last_contacted_on: Date.current,
          note: "said hi",
          updated_by: @admin
        )

        stale_contact = User.create!(
          email_address: "stale-contact-#{SecureRandom.hex(4)}@example.com",
          name: "Contacted long ago",
          password: "password12345",
          password_confirmation: "password12345",
          onboarding_completed_at: nil
        )
        TesterContact.create!(
          user: stale_contact,
          channel: "email",
          last_contacted_on: 4.days.ago.to_date,
          note: "old note",
          updated_by: @admin
        )

        needs = Testers.call(filter: Testers::FILTER_NEEDS_MESSAGE).map { |row| row.user.name }
        everyone = Testers.call(filter: Testers::FILTER_EVERYONE).map { |row| row.user.name }

        assert_includes needs, "Needs ping"
        assert_includes needs, "Contacted long ago"
        assert_not_includes needs, "Contacted today"
        assert_not_includes needs, "Fresh win"
        assert_includes everyone, "Contacted today"
        assert_includes everyone, "Fresh win"
      end
    end

    test "loads contacts in one batched query" do
      travel_to Time.zone.parse("2026-11-18 12:00:00") do
        @user.update!(onboarding_completed_at: nil)
        TesterContact.create!(
          user: @user,
          channel: "whatsapp",
          details: "353872346580",
          note: "hi",
          updated_by: @admin
        )

        row = row_for(@user)
        assert_equal "whatsapp", row.contact.channel
        assert_equal "353872346580", row.contact.details
      end
    end

    test "query count stays flat for 1 vs 20 users" do
      travel_to Time.zone.parse("2026-11-18 12:00:00") do
        one_count = count_queries { Testers.call(filter: Testers::FILTER_EVERYONE) }

        18.times do |index|
          User.create!(
            email_address: "tester-bulk-#{index}-#{SecureRandom.hex(3)}@example.com",
            name: "Bulk #{index}",
            password: "password12345",
            password_confirmation: "password12345",
            onboarding_completed_at: 2.weeks.ago
          )
        end

        twenty_count = count_queries { Testers.call(filter: Testers::FILTER_EVERYONE) }
        assert_equal one_count, twenty_count
        assert_operator one_count, :<=, 13
      end
    end

    private

    def row_for(user)
      Testers.call(filter: Testers::FILTER_EVERYONE).find { |row| row.user.id == user.id }
    end

    def plant_one_shot_win!(user, completed_at:)
      seed_climb!(user, today_mission: "Tester win #{SecureRandom.hex(3)}") unless user.strategy_goals.battles.exists?
      battle = user.strategy_goals.battles
        .where.not(repeat: Testers::RECURRING_REPEATS)
        .order(:id)
        .last
      battle ||= user.strategy_goals.battles.order(:id).last
      battle.update!(completed_at: completed_at, repeat: nil)
      battle
    end

    def count_queries
      queries = 0
      callback = lambda do |_name, _start, _finish, _id, payload|
        next if payload[:name] == "SCHEMA" || payload[:name] == "TRANSACTION"

        queries += 1 if payload[:sql].present?
      end

      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        yield
      end
      queries
    end
  end
end
