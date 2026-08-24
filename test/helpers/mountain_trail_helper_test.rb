# frozen_string_literal: true

require "test_helper"

class MountainTrailHelperTest < ActionView::TestCase
  include MountainTrailHelper

  test "day count is one-indexed from journey created_at" do
    journey = Struct.new(:created_at).new(9.days.ago.beginning_of_day)
    assert_equal 10, mountain_trail_day_count(journey)
  end

  test "day count is 1 when journey blank" do
    assert_equal 1, mountain_trail_day_count(nil)
  end

  test "today card shows badge when open battles exist" do
    card = mountain_trail_today_card(open_battles: [ Object.new, Object.new ], won_today: 0)
    assert card[:badge]
    assert card[:busy]
    assert_equal 2, card[:count]
  end

  test "today card rest state when quiet" do
    card = mountain_trail_today_card(open_battles: [], won_today: 0)
    assert_not card[:badge]
    assert_not card[:busy]
    assert_match(/rest/i, card[:sub])
  end

  test "peak tagline falls back to default" do
    assert_equal I18n.t("strategy.rpg.trail.peak_tagline_default"), mountain_trail_peak_tagline(nil)
  end
end
