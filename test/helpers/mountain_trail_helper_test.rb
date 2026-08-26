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

  test "today card plants first when the trail is empty" do
    card = mountain_trail_today_card(projects: [], open_battles: [], won_today: 0)
    assert_equal "plant_first", card[:mode]
    assert_match(/plant your first camp/i, card[:headline])
    assert_not card[:busy]
  end

  test "today card names how many battles to do" do
    battle = Struct.new(:completed_at, :title, :parent_id, keyword_init: true).new(
      completed_at: nil, title: "Pitch the tent", parent_id: 11
    )
    extra = Struct.new(:completed_at, :title, :parent_id, keyword_init: true).new(
      completed_at: nil, title: "Second fight", parent_id: 11
    )
    third = Struct.new(:completed_at, :title, :parent_id, keyword_init: true).new(
      completed_at: nil, title: "Third fight", parent_id: 11
    )
    camp = Struct.new(:id, :completed?, :pages_mode?, :children, :trail_x, :trail_y, :title).new(
      11, false, false, [ battle ], 0.5, 0.7, "Base camp"
    )
    card = mountain_trail_today_card(projects: [ camp ], open_battles: [ battle ], won_today: 0)
    assert_equal "win_next", card[:mode]
    assert_match(/1 battle to do/i, card[:headline])
    assert_match(/today/i, card[:sub])
    assert_equal 1, card[:count]
    assert_nil card[:camp_id]
    assert card[:busy]

    many = mountain_trail_today_card(
      projects: [ camp ],
      open_battles: [ battle, extra, third ],
      won_today: 0
    )
    assert_match(/3 battles to do/i, many[:headline])
    assert_equal 3, many[:count]
    assert_not many[:badge]
  end

  test "today card asks to add a battle on an empty camp" do
    camp = Struct.new(:id, :completed?, :pages_mode?, :children, :trail_x, :trail_y, :title).new(
      4, false, false, [], 0.5, 0.72, "Ridge"
    )
    card = mountain_trail_today_card(projects: [ camp ], open_battles: [], won_today: 0)
    assert_equal "add_battle", card[:mode]
    assert_equal 4, card[:camp_id]
    assert_match(/ridge/i, card[:sub])
  end

  test "today card cheers when today’s battles are already won" do
    won = Struct.new(:day?, :holding?, :completed?).new(true, false, true)
    camp = Struct.new(:id, :completed?, :pages_mode?, :children, :trail_x, :trail_y, :title).new(
      8, false, false, [ won ], 0.5, 0.7, "Base camp"
    )
    card = mountain_trail_today_card(projects: [ camp ], open_battles: [], won_today: 2)
    assert_equal "cheer", card[:mode]
    assert_match(/all clear/i, card[:headline])
    assert_match(/2/, card[:sub])
  end

  test "today card plants next when the trail is quiet" do
    won = Struct.new(:day?, :holding?, :completed?).new(true, false, true)
    camp = Struct.new(:id, :completed?, :pages_mode?, :children, :trail_x, :trail_y, :title).new(
      8, false, false, [ won ], 0.5, 0.7, "Base camp"
    )
    card = mountain_trail_today_card(projects: [ camp ], open_battles: [], won_today: 0)
    assert_equal "plant_next", card[:mode]
    assert_match(/plant the next camp/i, card[:headline])
  end

  test "peak tagline falls back to default" do
    assert_equal I18n.t("strategy.rpg.trail.peak_tagline_default"), mountain_trail_peak_tagline(nil)
  end

  test "climb fraction is zero with no projects" do
    assert_in_delta 0.0, mountain_trail_climb_fraction([]), 0.001
  end

  test "camps done counts completed camps on the full path" do
    done = Struct.new(:completed?).new(true)
    open = Struct.new(:completed?).new(false)
    assert_equal 1, mountain_trail_camps_done([ done, open ])
    assert_in_delta 0.5, mountain_trail_climb_fraction([ done, open ]), 0.001
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

  test "layout keeps planted tent pins fixed without lifting labels" do
    p1 = Struct.new(:id, :trail_x, :trail_y, keyword_init: true).new(id: 1, trail_x: 0.5, trail_y: 0.55)
    p2 = Struct.new(:id, :trail_x, :trail_y, keyword_init: true).new(id: 2, trail_x: 0.52, trail_y: 0.56)
    layout = mountain_trail_layout([ p1, p2 ])
    assert_in_delta 0.55, layout[1][:y], 0.0001
    assert_in_delta 0.56, layout[2][:y], 0.0001
    assert_in_delta 0.55, layout[1][:label_y], 0.0001
    assert_in_delta 0.56, layout[2][:label_y], 0.0001
    assert layout.values.all? { |slot| slot[:leader_h].to_f.zero? }
  end

  test "auto slot matches the renderer for unplaced camps" do
    slot = MountainTrailHelper::AutoSlot.call(index: 0, total: 2)
    other = MountainTrailHelper::AutoSlot.call(index: 1, total: 2)
    assert_in_delta MountainTrailHelper::TRAIL_Y_MIN, slot[:trail_y], 0.0001
    assert_in_delta MountainTrailHelper::TRAIL_Y_MAX, other[:trail_y], 0.0001
    unplaced = Struct.new(:id, :trail_x, :trail_y, keyword_init: true).new(id: 9, trail_x: nil, trail_y: nil)
    layout = mountain_trail_slot(unplaced, index: 0, total: 2)
    assert_in_delta slot[:trail_x], layout[:x], 0.0001
    assert_in_delta slot[:trail_y], layout[:y], 0.0001
    assert_not layout[:placed]
  end

  test "layout keeps packed tents on their planted coords" do
    camps = (1..9).map do |i|
      Struct.new(:id, :trail_x, :trail_y, keyword_init: true).new(
        id: i, trail_x: 0.5, trail_y: 0.55
      )
    end
    layout = mountain_trail_layout(camps)
    assert layout.values.all? { |slot| (slot[:y] - slot[:anchor_y]).abs < 0.0001 }
    assert layout.values.all? { |slot| (slot[:y] - 0.55).abs < 0.0001 }
    assert layout.values.all? { |slot| slot[:leader_h].to_f.zero? }
  end

  test "place mode clamp constants match mockup ranges" do
    assert_in_delta 0.03, MountainTrailHelper::PLACE_X_MIN, 0.0001
    assert_in_delta 0.97, MountainTrailHelper::PLACE_X_MAX, 0.0001
    assert_in_delta 0.03, MountainTrailHelper::PLACE_Y_MIN, 0.0001
    assert_in_delta 0.985, MountainTrailHelper::PLACE_Y_MAX, 0.0001
    assert_in_delta 0.95, MountainTrailHelper::BASE_YFRAC, 0.0001
  end

  test "seventh plant starter stops a bad habit" do
    starters = mountain_trail_plant_starters
    assert_equal 7, starters.size
    habit = starters.find { |s| s[:key] == "habit" }
    assert habit
    assert_equal "Stop a bad habit", habit[:label]
  end

  test "camp shadow leans away from peak light" do
    shadow = mountain_trail_camp_shadow({ x: 0.3, y: 0.5 })
    assert shadow[:dx].negative?
    assert shadow[:width].positive?
    assert shadow[:opacity].between?(0.2, 0.5)
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
