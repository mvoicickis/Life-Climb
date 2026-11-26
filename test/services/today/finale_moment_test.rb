# frozen_string_literal: true

require "test_helper"

module Today
  class FinaleMomentTest < ActiveSupport::TestCase
    setup do
      @user = users(:one)
      @user.daily_todos.delete_all
      @zone = "Europe/Berlin"
      @user.create_notification_preference!(time_zone: @zone) unless @user.notification_preference
      @user.notification_preference.update!(time_zone: @zone)
      @today = Date.new(2026, 8, 6)
      @user.update!(last_finale_on: nil) if @user.has_attribute?(:last_finale_on)
    end

    test "presents only when all_clear and once per local day" do
      skip unless @user.has_attribute?(:last_finale_on)

      travel_to zone_time(2026, 8, 6, 12) do
        health = BattlefieldHealth::Result.new(
          hp: 100,
          done_count: 2,
          total_count: 2,
          open_count: 0,
          band: :neutral,
          risk_icon: "✓",
          risk_note: "",
          result_title: ""
        )

        secret = "SECRET GOAL XYZ"
        finale = FinaleMoment.present_for!(
          user: @user,
          health: health,
          goal_title: secret,
          camp: { camp_current: 1, camp_count: 4, percent: 25 }
        )
        assert_equal 2, finale.battles_today
        assert_equal secret, finale.goal_title
        assert_equal 1, finale.camp_current
        assert_equal 4, finale.camp_total
        assert_in_delta 0.25, finale.camp_fill, 0.001
        assert_equal I18n.t("dash.finale.share_text"), finale.share_text
        refute_includes finale.share_text, secret
        assert_includes finale.share_text, "lifeclimb.app"
        assert_equal @today, @user.reload.last_finale_on

        again = FinaleMoment.present_for!(
          user: @user,
          health: health,
          goal_title: secret,
          camp: { camp_current: 1, camp_count: 4, percent: 25 }
        )
        assert_nil again
      end
    end

    test "skips when not all_clear or empty day" do
      skip unless @user.has_attribute?(:last_finale_on)

      travel_to zone_time(2026, 8, 6, 12) do
        open = BattlefieldHealth::Result.new(
          hp: 50,
          done_count: 1,
          total_count: 2,
          open_count: 1,
          band: :neutral,
          risk_icon: "",
          risk_note: "",
          result_title: ""
        )
        assert_nil FinaleMoment.present_for!(
          user: @user,
          health: open,
          goal_title: "Goal",
          camp: nil
        )

        empty = BattlefieldHealth::Result.new(
          hp: 0,
          done_count: 0,
          total_count: 0,
          open_count: 0,
          band: :neutral,
          risk_icon: "",
          risk_note: "",
          result_title: ""
        )
        assert_nil FinaleMoment.present_for!(
          user: @user,
          health: empty,
          goal_title: "Goal",
          camp: nil
        )
        assert_nil @user.reload.last_finale_on
      end
    end

    private

    def zone_time(year, month, day, hour)
      Time.find_zone!(@zone).local(year, month, day, hour, 0, 0)
    end
  end
end
