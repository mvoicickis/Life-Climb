# frozen_string_literal: true

require "test_helper"

class EndOfDayHelperTest < ActionView::TestCase
  include ApplicationHelper

  test "end_of_day_recap_stats uses singular battle when total is one" do
    health = Today::BattlefieldHealth.call(open_count: 0, total_count: 1)

    assert_equal "You won 1 of 1 battle. You kept all your health.", end_of_day_recap_stats(health)
  end

  test "end_of_day_recap_stats uses plain language at full health" do
    health = Today::BattlefieldHealth.call(open_count: 0, total_count: 3)

    assert_equal "You won 3 of 3 battles. You kept all your health.", end_of_day_recap_stats(health)
  end

  test "end_of_day_recap_stats uses plain language at partial health" do
    health = Today::BattlefieldHealth.call(open_count: 1, total_count: 3)

    assert_includes end_of_day_recap_stats(health), "You won 2 of 3 battles"
    assert_includes end_of_day_recap_stats(health), "67 percent"
  end

  test "end_of_day_share_text uses goal and battle count" do
    health = Today::BattlefieldHealth.call(open_count: 0, total_count: 3)
    journey = LifeJourney.new(title: "Journey")

    text = end_of_day_share_text(health, strategy_goal: nil, journey: journey)
    assert_includes text, "3 battles"
    assert_includes text, "Journey"
    assert_includes text, "lifeclimb.app"
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
