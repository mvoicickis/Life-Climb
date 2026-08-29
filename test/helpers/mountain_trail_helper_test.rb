# frozen_string_literal: true

require "test_helper"

class MountainTrailHelperTest < ActionView::TestCase
  include MountainTrailHelper
  include ClimbTestHelper

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

  test "camp status is empty, ready, or cleared" do
    empty = Struct.new(:pages_mode?, :quantified?, :children, :completed?).new(false, false, [], false)
    assert_equal "Nothing planned", mountain_trail_camp_status(empty)

    done = Struct.new(:day?, :holding?, :completed?).new(true, false, true)
    open = Struct.new(:day?, :holding?, :completed?).new(true, false, false)
    cleared = Struct.new(:pages_mode?, :quantified?, :children, :completed?).new(false, false, [ done ], false)
    assert_equal "All cleared", mountain_trail_camp_status(cleared)

    mixed = Struct.new(:pages_mode?, :quantified?, :children, :completed?).new(false, false, [ done, open, open ], false)
    assert_match(/2 battles ready/, mountain_trail_camp_status(mixed))
  end

  test "spur path is a quadratic from the dirt curve" do
    d = mountain_trail_spur_d(0.5, 0.7)
    assert_match(/\AM[\d.]+ [\d.]+ Q /, d)
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

  test "layout keeps planted tent pins on the dirt path without lifting labels" do
    p1 = Struct.new(:id, :trail_x, :trail_y, keyword_init: true).new(id: 1, trail_x: 0.5, trail_y: 0.55)
    p2 = Struct.new(:id, :trail_x, :trail_y, keyword_init: true).new(id: 2, trail_x: 0.52, trail_y: 0.56)
    layout = mountain_trail_layout([ p1, p2 ])
    s1 = MountainTrailHelper::AutoSlot.snap(0.5, 0.55)
    s2 = MountainTrailHelper::AutoSlot.snap(0.52, 0.56)
    assert_in_delta s1[:trail_y], layout[1][:y], 0.0001
    assert_in_delta s2[:trail_y], layout[2][:y], 0.0001
    assert_in_delta s1[:trail_y], layout[1][:label_y], 0.0001
    assert_in_delta s2[:trail_y], layout[2][:label_y], 0.0001
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

  test "snap pulls a point in the grass onto the dirt path" do
    on_path = MountainTrailHelper::AutoSlot.snap(0.5, 0.55)
    assert_in_delta on_path[:trail_x], MountainTrailHelper::AutoSlot.x_for(on_path[:trail_y]), 0.02

    grass = MountainTrailHelper::AutoSlot.snap(0.12, 0.55)
    assert grass[:trail_x] > 0.35
    assert grass[:trail_x] < 0.7
    assert_in_delta 0.55, grass[:trail_y], 0.08
  end

  test "layout keeps packed tents on their planted coords" do
    camps = (1..9).map do |i|
      Struct.new(:id, :trail_x, :trail_y, keyword_init: true).new(
        id: i, trail_x: 0.5, trail_y: 0.55
      )
    end
    layout = mountain_trail_layout(camps)
    expected = MountainTrailHelper::AutoSlot.snap(0.5, 0.55)
    assert layout.values.all? { |slot| (slot[:y] - slot[:anchor_y]).abs < 0.0001 }
    assert layout.values.all? { |slot| (slot[:y] - expected[:trail_y]).abs < 0.0001 }
    assert layout.values.all? { |slot| slot[:leader_h].to_f.zero? }
  end

  test "layout pulls a grass-planted tent onto the dirt path" do
    camp = Struct.new(:id, :trail_x, :trail_y, keyword_init: true).new(
      id: 1, trail_x: 0.12, trail_y: 0.55
    )
    layout = mountain_trail_layout([ camp ])
    expected = MountainTrailHelper::AutoSlot.snap(0.12, 0.55)
    assert_in_delta expected[:trail_x], layout[1][:x], 0.0001
    assert_in_delta expected[:trail_y], layout[1][:y], 0.0001
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

  test "sort projects orders by position then id" do
    second = Struct.new(:id, :position).new(2, 1)
    first = Struct.new(:id, :position).new(1, 0)
    assert_equal [ first, second ], mountain_trail_sort_projects([ second, first ])
  end

  test "open camps returns position-sorted incomplete projects" do
    @user = users(:one)
    Onboarding::Run.call(
      user: @user, area_key: "career", title: "Ship", ideal_scene: "Live",
      current_reality: "Build", next_win: "Launch", today_mission: "Test", closer_percent: 20,
      route_mission: true
    )
    journey = @user.reload.primary_focused_journey
    area = journey.life_area
    goal = @user.strategy_goals.for_kind("goal").roots.first
    plan = goal.children.create!(
      user: @user, life_area: area, life_journey: journey,
      horizon: "plan", title: "Path", position: 0
    )
    lower = plan.children.create!(
      user: @user, life_area: area, life_journey: journey,
      horizon: "project", title: "Lower", position: 1, trail_x: 0.5, trail_y: 0.8
    )
    summit = plan.children.create!(
      user: @user, life_area: area, life_journey: journey,
      horizon: "project", title: "Summit", position: 0, trail_x: 0.5, trail_y: 0.4
    )

    assert_equal [ summit, lower ], mountain_trail_open_camps(plan.reload)
  end

  test "base camp add parent is nil when no projects" do
    assert_nil mountain_trail_base_camp_add_parent([])
  end

  test "base camp add parent picks idle lowest camp when no battles exist" do
    summit = Struct.new(:id, :position, :completed?, :pages_mode?, :children, :trail_x, :trail_y).new(
      1, 0, false, false, [], 0.5, 0.4
    )
    lower = Struct.new(:id, :position, :completed?, :pages_mode?, :children, :trail_x, :trail_y).new(
      2, 1, false, false, [], 0.5, 0.8
    )

    assert_equal lower, mountain_trail_base_camp_add_parent([ summit, lower ])
  end

  test "base camp add parent picks current camp with open battles over summit" do
    battle = Struct.new(:day?, :holding?, :completed?).new(true, false, false)
    summit = Struct.new(:id, :position, :completed?, :pages_mode?, :children, :trail_x, :trail_y).new(
      1, 0, false, false, [], 0.5, 0.4
    )
    lower = Struct.new(:id, :position, :completed?, :pages_mode?, :children, :trail_x, :trail_y).new(
      2, 1, false, false, [ battle ], 0.5, 0.8
    )

    assert_equal lower, mountain_trail_base_camp_add_parent([ summit, lower ])
  end

  test "base camp add parent falls back to first pages camp when all are pages mode" do
    pages = Struct.new(:id, :position, :completed?, :pages_mode?, :children, :trail_x, :trail_y).new(
      1, 0, false, true, [], 0.5, 0.6
    )

    assert_equal pages, mountain_trail_base_camp_add_parent([ pages ])
  end

  test "fire level scales with battle count" do
    days = Array.new(4) { Struct.new(:day?, :holding?).new(true, false) }
    project = Struct.new(:completed?, :pages_mode?, :children).new(false, false, days)
    assert_equal 1, mountain_trail_fire_level(project)
  end

  test "energy rises with wins and open battles" do
    battle_open = Struct.new(:day?, :holding?, :completed?).new(true, false, false)
    battle_won = Struct.new(:day?, :holding?, :completed?).new(true, false, true)
    project = Struct.new(:children).new([ battle_open, battle_won ])
    assert mountain_trail_energy([ project ]) > 0.1
  end

  test "base due hides a daily already rolled to tomorrow" do
    due = Struct.new(:repeat_daily?, :completed?, :scheduled_on).new(true, false, Date.current)
    later = Struct.new(:repeat_daily?, :completed?, :scheduled_on).new(true, false, Date.current + 1)
    done = Struct.new(:repeat_daily?, :completed?, :scheduled_on).new(true, true, Date.current)
    assert mountain_trail_base_due?(due)
    assert_not mountain_trail_base_due?(later)
    assert_not mountain_trail_base_due?(done)
  end

  test "done today uses completed_at for one-shot battles" do
    user = users(:one)
    seed_climb!(user, today_mission: "Ship auth")
    battle = user.strategy_goals.find_by!(horizon: "day", title: "Ship auth")
    assert_not mountain_trail_done_today?(battle, user: user)

    battle.complete!
    assert mountain_trail_done_today?(battle, user: user)
  end

  test "done today uses today's todo for daily battles without setting completed_at" do
    user = users(:one)
    seed_climb!(user, today_mission: "Stretch daily")
    battle = user.strategy_goals.find_by!(horizon: "day", title: "Stretch daily")
    battle.update!(repeat: "daily")
    Strategy::CascadeToDaily.call(user: user, life_area: battle.life_area, from: Date.current, to: Date.current)
    todo = user.daily_todos.for_day.find_by!(strategy_goal_id: battle.id)

    assert_not mountain_trail_done_today?(battle, user: user)
    todo.update!(completed_at: Time.current)
    mountain_trail_preload_done_today!(user, [ battle ])
    assert mountain_trail_done_today?(battle, user: user)
    assert_nil battle.reload.completed_at
  end

  test "preload avoids per-row todo queries" do
    user = users(:one)
    seed_climb!(user, today_mission: "Query guard")
    battle = user.strategy_goals.find_by!(horizon: "day", title: "Query guard")
    battle.update!(repeat: "daily")
    Strategy::CascadeToDaily.call(user: user, life_area: battle.life_area, from: Date.current, to: Date.current)
    todo = user.daily_todos.for_day.find_by!(strategy_goal_id: battle.id)
    todo.update!(completed_at: Time.current)
    mountain_trail_preload_done_today!(user, [ battle ])

    queries = 0
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*_, payload|
      queries += 1 unless payload[:name] == "SCHEMA"
    end
    begin
      assert mountain_trail_done_today?(battle, user: user)
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end
    assert_equal 0, queries
  end

  test "camp progress counts daily wins as won today" do
    user = users(:one)
    journey = seed_climb!(user, today_mission: "Camp progress")
    battle = user.strategy_goals.find_by!(horizon: "day", title: "Camp progress")
    project = battle.parent
    battle.update!(repeat: "daily")
    Strategy::CascadeToDaily.call(user: user, life_area: journey.life_area, from: Date.current, to: Date.current)
    todo = user.daily_todos.for_day.find_by!(strategy_goal_id: battle.id)
    mountain_trail_preload_done_today!(user, [ battle ])

    before = mountain_trail_camp_progress(project, user: user)
    assert_equal 1, before[:open]
    assert_equal 0, before[:won]

    todo.update!(completed_at: Time.current)
    mountain_trail_preload_done_today!(user, [ battle ])
    after = mountain_trail_camp_progress(project, user: user)
    assert_equal 0, after[:open]
    assert_equal 1, after[:won]
  end

  test "base quantity habits scopes to journey quantity checkin and ignores on_home" do
    user = users(:one)
    seed_climb!(user, today_mission: "Ship auth")
    journey = user.primary_focused_journey
    user.habits.destroy_all

    quantity = user.habits.create!(
      name: "Push-Ups",
      unit: "reps",
      points: 5,
      frequency: "daily",
      active: true,
      show_on_home: false,
      stat_type: "growth",
      goal: 25,
      quantity_checkin: true,
      life_journey_id: journey.id
    )
    binary = user.habits.create!(
      name: "Meditate",
      unit: "times",
      points: 5,
      frequency: "daily",
      active: true,
      show_on_home: true,
      stat_type: "growth",
      goal: 1,
      quantity_checkin: false,
      life_journey_id: journey.id
    )
    second_quantity = user.habits.create!(
      name: "Pages",
      unit: "pages",
      points: 5,
      frequency: "daily",
      active: true,
      show_on_home: false,
      stat_type: "growth",
      goal: 10,
      quantity_checkin: true,
      life_journey_id: journey.id
    )
    other_journey = user.life_journeys.create!(
      life_area: journey.life_area,
      title: "Side climb",
      ideal_scene: "Elsewhere",
      current_reality: "Other",
      next_win: "Other win",
      gap_percent: 80,
      status: "active"
    )
    wrong = user.habits.create!(
      name: "Other climb",
      unit: "pages",
      points: 5,
      frequency: "daily",
      active: true,
      show_on_home: true,
      stat_type: "growth",
      goal: 10,
      quantity_checkin: true,
      life_journey_id: other_journey.id
    )
    inactive = user.habits.create!(
      name: "Old habit",
      unit: "pages",
      points: 5,
      frequency: "daily",
      active: false,
      show_on_home: true,
      stat_type: "growth",
      goal: 10,
      quantity_checkin: true,
      life_journey_id: journey.id
    )

    habits = mountain_trail_base_quantity_habits(journey: journey, user: user)
    assert_equal [ quantity, second_quantity ].sort_by(&:id), habits.sort_by(&:id)
    refute_includes habits, binary
    refute_includes habits, wrong
    refute_includes habits, inactive
  end

  test "base quantity habits returns empty when journey blank" do
    user = users(:one)
    assert_equal [], mountain_trail_base_quantity_habits(journey: nil, user: user)
  end
end
