# frozen_string_literal: true

require "test_helper"

module ClimbTogether
  class PartnerDayWinsTest < ActiveSupport::TestCase
    setup do
      @viewer = users(:one)
      @partner = users(:two)
      ClimbPartnership.delete_all
      HighFive.delete_all
      @zone = "Europe/Berlin"
      @partner.create_notification_preference!(time_zone: @zone) unless @partner.notification_preference
      @partner.notification_preference.update!(time_zone: @zone)
    end

    test "returns nil when there is no active partner" do
      assert_nil PartnerDayWins.call(viewer: @viewer)
    end

    test "returns zero wins when partner has none today" do
      travel_to Time.find_zone!(@zone).local(2026, 11, 17, 12, 0, 0) do
        seed_climb!(@partner, today_mission: "Quiet day")
        invite = Invite.call(user: @viewer)
        Accept.call(user: @partner, token: invite.token)

        day = PartnerDayWins.call(viewer: @viewer)
        assert_equal @partner, day.partner
        assert_equal 0, day.count
        assert_nil day.battle
        refute day.cheered
      end
    end

    test "counts partner wins and picks the latest battle" do
      travel_to Time.find_zone!(@zone).local(2026, 11, 17, 15, 0, 0) do
        seed_climb!(@partner, today_mission: "First win")
        allow_extra_climbs!(@partner)
        battle_a = @partner.strategy_goals.find_by!(horizon: "day", title: "First win")
        battle_a.update!(completed_at: Time.find_zone!(@zone).local(2026, 11, 17, 9, 0, 0))

        journey = @partner.primary_focused_journey
        project = @partner.strategy_goals.for_kind("project").where(life_journey_id: journey.id).first
        battle_b = add_todays_battle!(
          user: @partner,
          project: project,
          journey: journey,
          title: "Later win"
        )
        battle_b.update!(completed_at: Time.find_zone!(@zone).local(2026, 11, 17, 14, 0, 0))

        invite = Invite.call(user: @viewer)
        Accept.call(user: @partner, token: invite.token)

        day = PartnerDayWins.call(viewer: @viewer)
        assert_equal 2, day.count
        assert_equal battle_b, day.battle
        assert_nil day.daily_todo
        refute day.cheered
      end
    end

    test "uses the partner local day not the viewer day" do
      tokyo = "Asia/Tokyo"
      @partner.notification_preference.update!(time_zone: tokyo)

      # 2026-11-17 23:30 in Tokyo is still Nov 17 there; early morning UTC Nov 17 is previous evening in Tokyo.
      travel_to Time.find_zone!(tokyo).local(2026, 11, 17, 10, 0, 0) do
        seed_climb!(@partner, today_mission: "Tokyo win")
        battle = @partner.strategy_goals.find_by!(horizon: "day", title: "Tokyo win")
        battle.update!(completed_at: Time.find_zone!(tokyo).local(2026, 11, 17, 8, 0, 0))

        invite = Invite.call(user: @viewer)
        Accept.call(user: @partner, token: invite.token)

        day = PartnerDayWins.call(viewer: @viewer)
        assert_equal 1, day.count
        assert_equal battle, day.battle
      end
    end

    test "cheered is true after a high-five on the partner local day" do
      travel_to Time.find_zone!(@zone).local(2026, 11, 17, 12, 0, 0) do
        seed_climb!(@partner, today_mission: "Cheer me")
        battle = @partner.strategy_goals.find_by!(horizon: "day", title: "Cheer me")
        battle.update!(completed_at: Time.find_zone!(@zone).local(2026, 11, 17, 9, 0, 0))
        invite = Invite.call(user: @viewer)
        Accept.call(user: @partner, token: invite.token)

        HighFives::Create.call(from: @viewer, battle: battle)

        day = PartnerDayWins.call(viewer: @viewer)
        assert day.cheered
        assert_equal 1, day.count
      end
    end

    test "query count stays flat" do
      travel_to Time.find_zone!(@zone).local(2026, 11, 17, 12, 0, 0) do
        seed_climb!(@partner, today_mission: "Query win")
        battle = @partner.strategy_goals.find_by!(horizon: "day", title: "Query win")
        battle.update!(completed_at: Time.find_zone!(@zone).local(2026, 11, 17, 9, 0, 0))
        invite = Invite.call(user: @viewer)
        Accept.call(user: @partner, token: invite.token)

        queries = 0
        callback = lambda do |_name, _start, _finish, _id, payload|
          next if payload[:name] == "SCHEMA" || payload[:name] == "TRANSACTION"

          queries += 1 if payload[:sql].present?
        end

        ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
          PartnerDayWins.call(viewer: @viewer)
        end

        assert_operator queries, :<=, 6, "expected fixed partner-day queries, got #{queries}"
      end
    end
  end
end
