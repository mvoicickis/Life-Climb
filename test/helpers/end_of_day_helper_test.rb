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
end
