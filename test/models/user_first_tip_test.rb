# frozen_string_literal: true

require "test_helper"

class UserFirstTipTest < ActiveSupport::TestCase
  test "mark_first_tip_seen! is idempotent" do
    user = users(:one)
    user.update!(support_milestones_shown: [])

    refute user.first_tip_seen?("circle")
    user.mark_first_tip_seen!("circle")
    assert user.reload.first_tip_seen?("circle")
    assert_includes user.support_milestones_shown, "first_tip_circle"

    shown = user.support_milestones_shown.dup
    user.mark_first_tip_seen!("circle")
    assert_equal shown, user.reload.support_milestones_shown
  end

  test "onboarding_local_day_index uses user timezone day" do
    user = users(:one)
    user.update!(onboarding_completed_at: 2.days.ago)

    assert_equal 2, user.onboarding_local_day_index
  end

  test "daily budget excludes circle and caps at two" do
    user = users(:one)
    user.update!(first_tips_daily: {})

    assert user.first_tip_daily_budget_available?

    user.record_first_tip_shown_today!("mountain")
    assert user.reload.first_tip_daily_budget_available?

    user.record_first_tip_shown_today!("camp")
    refute user.reload.first_tip_daily_budget_available?

    user.record_first_tip_shown_today!("circle")
    refute user.reload.first_tip_daily_budget_available?
  end

  test "stale first_tips_daily resets on read" do
    user = users(:one)
    user.update!(
      first_tips_daily: {
        "on" => (user.local_today - 1).iso8601,
        "keys" => %w[mountain camp]
      }
    )

    assert user.first_tip_daily_budget_available?
    assert_equal({}, user.reload.first_tips_daily)
  end
end