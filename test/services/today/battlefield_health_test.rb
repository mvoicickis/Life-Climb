# frozen_string_literal: true

require "test_helper"

class Today::BattlefieldHealthTest < ActiveSupport::TestCase
  test "hp reflects won share of today's battles" do
    result = Today::BattlefieldHealth.call(open_count: 3, total_count: 4)
    assert_equal 25, result.hp
    assert_equal 1, result.done_count
    assert_equal 3, result.open_count
    assert result.danger?
  end

  test "all clear at full health" do
    result = Today::BattlefieldHealth.call(open_count: 0, total_count: 4)
    assert_equal 100, result.hp
    assert result.all_clear?
    assert result.safe?
  end

  test "empty day defaults to 100 hp" do
    result = Today::BattlefieldHealth.call(open_count: 0, total_count: 0)
    assert_equal 100, result.hp
    assert result.empty?
  end
end
