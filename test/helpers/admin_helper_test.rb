# frozen_string_literal: true

require "test_helper"

class AdminHelperTest < ActionView::TestCase
  include AdminHelper

  test "activity status is green for today or yesterday" do
    travel_to Time.zone.parse("2026-08-30 12:00:00") do
      assert_equal :green, admin_funnel_activity_status(Time.current)[:level]
      assert_equal :green, admin_funnel_activity_status(1.day.ago)[:level]
    end
  end

  test "activity status is amber for two to six days ago" do
    travel_to Time.zone.parse("2026-08-30 12:00:00") do
      assert_equal :amber, admin_funnel_activity_status(2.days.ago)[:level]
      assert_equal :amber, admin_funnel_activity_status(6.days.ago)[:level]
    end
  end

  test "activity status is muted for seven plus days or never" do
    travel_to Time.zone.parse("2026-08-30 12:00:00") do
      assert_equal :muted, admin_funnel_activity_status(7.days.ago)[:level]
      assert_equal :muted, admin_funnel_activity_status(nil)[:level]
    end
  end
end
