# frozen_string_literal: true

require "test_helper"

module ClimbTogether
  class SideBySideTest < ActiveSupport::TestCase
    setup do
      @viewer = users(:one)
      @partner = users(:two)
      ClimbPartnership.delete_all
      HighFive.delete_all
      @zone = "Europe/Berlin"
      @viewer.create_notification_preference!(time_zone: @zone) unless @viewer.notification_preference
      @viewer.notification_preference.update!(time_zone: @zone)
      @partner.create_notification_preference!(time_zone: @zone) unless @partner.notification_preference
      @partner.notification_preference.update!(time_zone: @zone)
    end

    test "returns nil when there is no active partner" do
      assert_nil SideBySide.call(viewer: @viewer)
    end

    test "builds you and partner cards with camp progress and weekly wins" do
      travel_to Time.find_zone!(@zone).local(2026, 11, 17, 12, 0, 0) do
        seed_climb!(@viewer, today_mission: "Viewer secret battle")
        seed_climb!(@partner, area_key: "self", today_mission: "Partner secret battle")
        battle = @partner.strategy_goals.find_by!(horizon: "day", title: "Partner secret battle")
        battle.update!(completed_at: Time.find_zone!(@zone).local(2026, 11, 17, 9, 0, 0))

        invite = Invite.call(user: @viewer)
        Accept.call(user: @partner, token: invite.token)

        result = SideBySide.call(viewer: @viewer)
        assert result.present?
        assert_equal I18n.t("climb_together.side.you"), result.you.name
        assert_equal @partner.display_name, result.partner.name
        assert_match(/Camp \d+ of \d+/, result.you.camp_of)
        assert_match(/Camp \d+ of \d+/, result.partner.camp_of)
        assert result.you.camp_name.present?
        assert result.partner.camp_name.present?
        refute result.you.picking_mountain
        refute result.partner.picking_mountain
        assert_equal 1, result.partner.wins_this_week
        assert_equal 0, result.you.wins_this_week
      end
    end

    test "partner week uses partner time zone not viewer time zone" do
      tokyo = "Asia/Tokyo"
      @partner.notification_preference.update!(time_zone: tokyo)
      @viewer.notification_preference.update!(time_zone: "America/Los_Angeles")

      travel_to Time.find_zone!(tokyo).local(2026, 11, 16, 10, 0, 0) do
        seed_climb!(@viewer, today_mission: "Viewer day")
        seed_climb!(@partner, area_key: "self", today_mission: "Tokyo week win")
        battle = @partner.strategy_goals.find_by!(horizon: "day", title: "Tokyo week win")
        battle.update!(completed_at: Time.find_zone!(tokyo).local(2026, 11, 16, 8, 0, 0))

        invite = Invite.call(user: @viewer)
        Accept.call(user: @partner, token: invite.token)

        result = SideBySide.call(viewer: @viewer)
        assert_equal 1, result.partner.wins_this_week
      end
    end

    test "partner without a focused goal shows picking a mountain" do
      travel_to Time.find_zone!(@zone).local(2026, 11, 17, 12, 0, 0) do
        seed_climb!(@viewer, today_mission: "Viewer day")
        invite = Invite.call(user: @viewer)
        Accept.call(user: @partner, token: invite.token)
        @partner.life_journeys.update_all(status: "archived", focus_position: nil)

        result = SideBySide.call(viewer: @viewer)
        assert result.partner.picking_mountain
        assert_nil result.partner.journey
        assert_nil result.partner.camp_of
        assert_nil result.partner.camp_name
      end
    end

    test "query count stays flat" do
      travel_to Time.find_zone!(@zone).local(2026, 11, 17, 12, 0, 0) do
        seed_climb!(@viewer, today_mission: "Viewer query")
        seed_climb!(@partner, area_key: "self", today_mission: "Partner query")
        invite = Invite.call(user: @viewer)
        Accept.call(user: @partner, token: invite.token)

        queries = 0
        callback = lambda do |_name, _start, _finish, _id, payload|
          next if payload[:name] == "SCHEMA" || payload[:name] == "TRANSACTION"

          queries += 1 if payload[:sql].present?
        end

        ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
          SideBySide.call(viewer: @viewer)
        end

        assert_operator queries, :<=, 40, "expected fixed side-by-side queries, got #{queries}"
      end
    end
  end
end
