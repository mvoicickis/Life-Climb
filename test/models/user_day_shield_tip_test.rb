# frozen_string_literal: true

require "test_helper"

class UserDayShieldTipTest < ActiveSupport::TestCase
  test "day_shield_tip helpers mark support_milestones_shown once" do
    user = users(:one)
    user.update!(support_milestones_shown: [])

    refute user.day_shield_tip_done?

    user.mark_day_shield_tip_done!
    assert user.reload.day_shield_tip_done?
    assert_includes user.support_milestones_shown, User::DAY_SHIELD_TIP_KEY

    shown = user.support_milestones_shown.dup
    user.mark_day_shield_tip_done!
    assert_equal shown, user.reload.support_milestones_shown
  end
end
