# frozen_string_literal: true

require "test_helper"

class Today::BattlefieldHealthTest < ActiveSupport::TestCase
  test "hp reflects won share of today's battles" do
    result = Today::BattlefieldHealth.call(open_count: 3, total_count: 4)
    assert_equal 25, result.hp
    assert_equal 1, result.done_count
    assert_equal 3, result.open_count
    assert result.neutral?
    refute result.danger?
    refute result.warn?
    refute result.safe?
  end

  test "all clear at full health" do
    result = Today::BattlefieldHealth.call(open_count: 0, total_count: 4)
    assert_equal 100, result.hp
    assert_equal 4, result.done_count
    assert result.all_clear?
    assert result.neutral?
    assert_equal "✓", result.risk_icon
  end

  test "open battles use forward-looking note without warning icon" do
    result = Today::BattlefieldHealth.call(open_count: 1, total_count: 1)
    assert_equal 0, result.hp
    assert_equal "", result.risk_icon
    assert_equal I18n.t("dash.battlefield.risk_open", count: 1), result.risk_note
    assert result.neutral?
  end

  test "empty day uses neutral band without cleared framing" do
    result = Today::BattlefieldHealth.call(open_count: 0, total_count: 0)
    assert_equal 0, result.hp
    assert result.empty?
    assert result.neutral?
    refute result.all_clear?
    refute result.safe?
    refute result.warn?
    refute result.danger?
    assert_equal "", result.risk_icon
    assert_equal I18n.t("dash.battlefield.risk_empty"), result.risk_note
    assert_equal I18n.t("dash.battlefield.recap_empty"), result.result_title
    refute_includes result.risk_note, "cleared"
  end
end
