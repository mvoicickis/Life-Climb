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

  test "climb fraction is zero with no projects" do
    assert_in_delta 0.0, mountain_trail_climb_fraction([]), 0.001
  end

  test "peak coordinates sit on default mountain photo summit" do
    assert_in_delta 0.566, MountainTrailHelper::PEAK_X, 0.001
    assert_in_delta 0.22, MountainTrailHelper::PEAK_Y, 0.001
  end

  test "point on curve returns x within trail bounds" do
    point = mountain_trail_point_on_curve(0.55)
    assert point[:x].between?(0.4, 0.7)
    assert_in_delta 0.55, point[:y], 0.001
  end

  test "footprints empty when no progress" do
    assert_empty mountain_trail_footprints([])
  end

  test "layout spreads overlapping camp signs downward" do
    p1 = Struct.new(:id, :trail_x, :trail_y, keyword_init: true).new(id: 1, trail_x: 0.5, trail_y: 0.55)
    p2 = Struct.new(:id, :trail_x, :trail_y, keyword_init: true).new(id: 2, trail_x: 0.52, trail_y: 0.56)
    layout = mountain_trail_layout([ p1, p2 ])
    assert layout[2][:y] - layout[1][:y] >= MountainTrailHelper::SIGN_MIN_GAP - 0.001
  end

  test "layout never packs camps above the trail floor under the summit" do
    camps = (1..9).map do |i|
      Struct.new(:id, :trail_x, :trail_y, keyword_init: true).new(
        id: i, trail_x: 0.5, trail_y: 0.55
      )
    end
    layout = mountain_trail_layout(camps)
    ys = layout.values.map { |slot| slot[:y].to_f }
    assert ys.min >= MountainTrailHelper::TRAIL_Y_MIN - 0.0001
    assert ys.max <= MountainTrailHelper::SIGN_FLOOR_Y + 0.0001
    assert ys.min > MountainTrailHelper::PEAK_Y
  end

  test "current project picks lowest open camp on trail" do
    battle = Struct.new(:day?, :holding?, :completed?).new(true, false, false)
    open_project = Struct.new(:id, :completed?, :pages_mode?, :children, :trail_x, :trail_y).new(
      1, false, false, [ battle ], 0.5, 0.7
    )
    other = Struct.new(:id, :completed?, :pages_mode?, :children, :trail_x, :trail_y).new(
      2, false, false, [ battle ], 0.5, 0.55
    )
    current = mountain_trail_current_project([ other, open_project ])
    assert_equal open_project, current
  end

  test "fire level scales with battle count" do
    days = Array.new(4) { Struct.new(:day?, :holding?).new(true, false) }
    project = Struct.new(:completed?, :pages_mode?, :children).new(false, false, days)
    assert_equal 1, mountain_trail_fire_level(project)
  end

  test "ghosts avoid peak band when projects exist" do
    p1 = Struct.new(:id, :trail_x, :trail_y, keyword_init: true).new(id: 1, trail_x: 0.5, trail_y: 0.55)
    layout = mountain_trail_layout([ p1 ])
    ghosts = mountain_trail_ghosts([ p1 ], layout: layout)
    ghosts.each do |g|
      assert g[:y] > MountainTrailHelper::PEAK_BAND_Y + 0.03,
             "ghost at #{g[:y]} should sit below peak band"
    end
  end

  test "energy rises with wins and open battles" do
    battle_open = Struct.new(:day?, :holding?, :completed?).new(true, false, false)
    battle_won = Struct.new(:day?, :holding?, :completed?).new(true, false, true)
    project = Struct.new(:children).new([ battle_open, battle_won ])
    assert mountain_trail_energy([ project ]) > 0.1
  end
end
