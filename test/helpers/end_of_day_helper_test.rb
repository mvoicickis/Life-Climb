# frozen_string_literal: true

require "test_helper"

class EndOfDayHelperTest < ActionView::TestCase
  include ApplicationHelper

  def current_user
    users(:one)
  end

  test "end_of_day_recap_stats uses singular battle when total is one" do
    health = Today::BattlefieldHealth.call(open_count: 0, total_count: 1)

    assert_equal "You won your only battle today.", end_of_day_recap_stats(health)
  end

  test "end_of_day_recap_stats uses plain language at full health" do
    health = Today::BattlefieldHealth.call(open_count: 0, total_count: 3)

    assert_equal "You won all 3 battles today.", end_of_day_recap_stats(health)
  end

  test "end_of_day_recap_stats uses plain language at partial health" do
    health = Today::BattlefieldHealth.call(open_count: 1, total_count: 3)

    assert_includes end_of_day_recap_stats(health), "You won 2 of 3 battles"
    assert_includes end_of_day_recap_stats(health), "2 of 3 battles"
  end

  test "end_of_day_share_text uses battle count only without goal title" do
    health = Today::BattlefieldHealth.call(open_count: 0, total_count: 3)
    secret = "SECRET GOAL XYZ"

    text = end_of_day_share_text(health)
    url = ReferralShareUrl.for(current_user)
    assert_equal I18n.t("dash.end_of_day.share_recap", count: 3, url: url), text
    assert_includes text, "3 battles"
    assert_includes text, "?r=#{current_user.referral_code}"
    refute_includes text, secret
  end

  test "end_of_day_share_text without referral code uses plain landing" do
    health = Today::BattlefieldHealth.call(open_count: 0, total_count: 1)
    user = User.new(referral_code: nil)
    text = end_of_day_share_text(health, user: user)

    assert_equal I18n.t(
      "dash.end_of_day.share_recap",
      count: 1,
      url: ReferralShareUrl.for(user)
    ), text
    refute_includes text, "?r="
  end

  test "end_of_day_battles_won_line uses singular copy" do
    health = Today::BattlefieldHealth.call(open_count: 0, total_count: 1)

    assert_equal "1 battle won", end_of_day_battles_won_line(health)
  end

  test "end_of_day_signoff_camp returns nil when no camps" do
    assert_nil end_of_day_signoff_camp(camps_total: 0, camps_completed: 0)
  end

  test "end_of_day_signoff_camp labels current camp" do
    camp = end_of_day_signoff_camp(camps_total: 6, camps_completed: 1)

    assert_equal 2, camp[:current]
    assert_equal 6, camp[:total]
    assert_includes camp[:label], "Camp 2 of 6"
  end
end
