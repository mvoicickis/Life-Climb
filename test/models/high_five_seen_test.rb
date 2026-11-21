# frozen_string_literal: true

require "test_helper"

class HighFiveSeenTest < ActiveSupport::TestCase
  include ClimbTestHelper

  setup do
    @viewer = users(:one)
    @partner = users(:two)
    HighFive.delete_all
    @zone = "Europe/Berlin"
    @viewer.create_notification_preference!(time_zone: @zone) unless @viewer.notification_preference
    @viewer.notification_preference.update!(time_zone: @zone)

    travel_to Time.find_zone!(@zone).local(2026, 11, 19, 11, 0, 0) do
      seed_climb!(@viewer, today_mission: "Viewer fight")
      @battle = @viewer.strategy_goals.find_by!(horizon: "day", title: "Viewer fight")
    end
  end

  test "unseen_received_today skips seen cheers and other days" do
    travel_to Time.find_zone!(@zone).local(2026, 11, 19, 11, 30, 0) do
      cheer = HighFive.create!(
        from_user: @partner,
        to_user: @viewer,
        strategy_goal: @battle
      )

      found = HighFive.unseen_received_today(to_user: @viewer)
      assert_equal cheer.id, found.id

      cheer.mark_seen!
      assert cheer.reload.seen_at.present?
      assert_nil HighFive.unseen_received_today(to_user: @viewer)
    end

    travel_to Time.find_zone!(@zone).local(2026, 11, 20, 11, 30, 0) do
      assert_nil HighFive.unseen_received_today(to_user: @viewer)
    end
  end

  test "mark_seen! is idempotent" do
    travel_to Time.find_zone!(@zone).local(2026, 11, 19, 11, 30, 0) do
      cheer = HighFive.create!(
        from_user: @partner,
        to_user: @viewer,
        strategy_goal: @battle
      )
      cheer.mark_seen!
      first = cheer.reload.seen_at
      travel 1.minute
      cheer.mark_seen!
      assert_equal first, cheer.reload.seen_at
    end
  end
end
