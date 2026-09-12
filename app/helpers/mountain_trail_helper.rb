# frozen_string_literal: true

# Places path projects on the Mountain V4 photo trail.
# Coordinates are fractions: x across the canvas, y down from the peak.
module MountainTrailHelper
  # Traced path on the default 1024×1536 mountain photo (yFrac, xFrac).
  TRAIL_CURVE = [
    [ 0.236, 0.545 ],
    [ 0.297, 0.549 ],
    [ 0.352, 0.562 ],
    [ 0.408, 0.536 ],
    [ 0.463, 0.512 ],
    [ 0.518, 0.555 ],
    [ 0.574, 0.531 ],
    [ 0.623, 0.488 ],
    [ 0.678, 0.457 ],
    [ 0.740, 0.462 ],
    [ 0.807, 0.518 ],
    [ 0.875, 0.549 ],
    [ 0.985, 0.586 ]
  ].freeze

  TRAIL_Y_MIN = 0.32
  TRAIL_Y_MAX = 0.88
  PEAK_X = 0.566
  # Default photo summit (baked-in flag tip on mountain_trail_default ≈ 0.22).
  PEAK_Y = 0.22

  # Terraced map (mountain-stages-bg-v2.webp 1080×1350) — front-edge anchors bottom→top.
  # Measured on the grass lip (lowest row of each shelf), not the back edge.
  MAP_ASPECT_WIDTH = 1080
  MAP_ASPECT_HEIGHT = 1350
  # Image anchors to the top of the map area; open-stage chrome uses --lp-open-stage-lift.
  MAP_WORLD_Y = "0%"
  MAP_ZOOM = 1.0
  # Front-edge y/x on mountain-stages-bg-v2.webp as fractions of image size.
  # Gaps between lips: T1–T2 18.7%, T2–T3 16.3%, T3–T4 13.6%.
  TERRACE_ANCHORS = {
    1 => { y: 0.7481, x: 0.4583, x_left: 0.2259, x_right: 0.7750, token: "bottom" },
    2 => { y: 0.5615, x: 0.4111, x_left: 0.2972, x_right: 0.6954, token: "second" },
    3 => { y: 0.3985, x: 0.4333, x_left: 0.3204, x_right: 0.6870, token: "third" },
    4 => { y: 0.2630, x: 0.4685, x_left: 0.3444, x_right: 0.7287, token: "top" }
  }.freeze
  OPEN_TERRACE_CAMP_CAP = 2
  LATER_TERRACE_CAMP_CAP = 3
  # Tent caption under camp markers — two lines; long names still truncate in Ruby.
  CAMP_TENT_TITLE_LIMIT = 24
  HUD_PLAN_TITLE_LIMIT = 24

  ACCENT_HEX = {
    "teal" => "#0f9488",
    "coral" => "#e8590c",
    "amber" => "#f1a208",
    "purple" => "#7c3aed",
    "blue" => "#4c6ef5",
    "green" => "#12a150",
    "pink" => "#d6336c",
    "gray" => "#57534e"
  }.freeze

  # Fixed star map from MountainV4 mockup: [x%, y%, opacity].
  MOUNTAIN_STARS = [
    [ 8, 10, 0.9 ], [ 15, 25, 0.6 ], [ 22, 8, 0.8 ], [ 30, 30, 0.5 ], [ 38, 14, 0.7 ],
    [ 45, 26, 0.55 ], [ 52, 9, 0.85 ], [ 60, 22, 0.6 ], [ 68, 12, 0.75 ], [ 76, 28, 0.5 ],
    [ 83, 16, 0.8 ], [ 90, 9, 0.65 ], [ 12, 35, 0.4 ], [ 70, 35, 0.45 ], [ 50, 4, 0.9 ],
    [ 25, 4, 0.7 ], [ 85, 4, 0.55 ], [ 5, 20, 0.5 ], [ 95, 20, 0.45 ]
  ].freeze

  # Mockup BASE_YFRAC — base camp + Today card sit on the photo near the trail foot.
  BASE_YFRAC = 0.95
  FOOT_BASE_Y = 0.94
  FOOT_TOP_Y = 0.28
  # Minimum trail-leg advance per battle win (display-only climber marker).
  CLIMBER_MIN_LEG_STEP = 0.12
  SIGN_MIN_GAP = 0.09
  SIGN_FLOOR_Y = 0.72
  PEAK_BAND_Y = 0.26
  # Place-mode tap range (mockup) — wider than the auto-layout trail band.
  PLACE_X_MIN = 0.03
  PLACE_X_MAX = 0.97
  PLACE_Y_MIN = 0.03
  PLACE_Y_MAX = 0.985

  PLANT_ICON_STARTERS = [
    { icon: "💪", key: "strong", color: "#e8590c" },
    { icon: "📖", key: "read", color: "#4c6ef5" },
    { icon: "💰", key: "save", color: "#0f9488" },
    { icon: "😴", key: "sleep", color: "#7950f2" },
    { icon: "🥗", key: "eat", color: "#22c55e" },
    { icon: "🗣", key: "language", color: "#e64980" },
    { icon: "🧹", key: "habit", color: "#f1a208" }
  ].freeze

  def mountain_trail_project_accent(project)
    project&.trail_accent_hex || mountain_trail_accent(project&.tagged_color_key)
  end

  def mountain_trail_photo_url(journey)
    if journey&.mountain_photo&.attached?
      url_for(journey.mountain_photo.variant(resize_to_limit: [ 1200, 1800 ]))
    else
      image_path("mountain-stages-bg-v2.webp")
    end
  rescue StandardError
    if journey&.mountain_photo&.attached?
      url_for(journey.mountain_photo)
    else
      image_path("mountain-stages-bg-v2.webp")
    end
  end

  def mountain_trail_all_projects(trail)
    strategy_climb_path_nodes(trail).filter_map(&:record).reject(&:holding?)
  end

  def mountain_trail_projects(trail)
    mountain_trail_all_projects(trail).reject(&:completed?)
  end

  # Shared auto-layout so show-pin and create use the same slot as the renderer.
  module AutoSlot
    module_function

    def call(index:, total:)
      y = y_for(index, total)
      { trail_x: x_for(y), trail_y: y }
    end

    def y_for(index, total)
      return 0.58 if total <= 0

      t = total == 1 ? 0.5 : index.to_f / (total - 1)
      (TRAIL_Y_MIN + t * (TRAIL_Y_MAX - TRAIL_Y_MIN)).clamp(TRAIL_Y_MIN, TRAIL_Y_MAX)
    end

    def x_for(y_frac)
      curve = TRAIL_CURVE
      return curve.first[1] if y_frac <= curve.first[0]
      return curve.last[1] if y_frac >= curve.last[0]

      (0...(curve.length - 1)).each do |i|
        y0, x0 = curve[i]
        y1, x1 = curve[i + 1]
        next unless y_frac >= y0 && y_frac <= y1

        k = (y_frac - y0) / (y1 - y0)
        return x0 + k * (x1 - x0)
      end

      0.5
    end

    # Nearest point on the painted dirt path (polyline of TRAIL_CURVE).
    def snap(trail_x, trail_y)
      x = trail_x.to_f
      y = trail_y.to_f
      curve = TRAIL_CURVE
      best_x = x
      best_y = y
      best_d = Float::INFINITY

      (0...(curve.length - 1)).each do |i|
        y0, x0 = curve[i]
        y1, x1 = curve[i + 1]
        dx = x1 - x0
        dy = y1 - y0
        len2 = (dx * dx) + (dy * dy)
        t = len2.zero? ? 0.0 : (((x - x0) * dx) + ((y - y0) * dy)) / len2
        t = t.clamp(0.0, 1.0)
        px = x0 + (t * dx)
        py = y0 + (t * dy)
        dist = ((px - x)**2) + ((py - y)**2)
        next unless dist < best_d

        best_d = dist
        best_x = px
        best_y = py
      end

      { trail_x: best_x, trail_y: best_y }
    end
  end

  # Returns { x:, y:, placed: } with x/y in 0..1 for CSS left/top %.
  def mountain_trail_slot(project, index:, total:)
    if project.trail_x.present? && project.trail_y.present?
      slot = AutoSlot.snap(project.trail_x, project.trail_y)
      return {
        x: slot[:trail_x].clamp(PLACE_X_MIN, PLACE_X_MAX),
        y: slot[:trail_y].clamp(PLACE_Y_MIN, PLACE_Y_MAX),
        placed: true
      }
    end

    y = AutoSlot.y_for(index, total)
    { x: AutoSlot.x_for(y), y: y, placed: false }
  end

  def mountain_trail_accent(color_key)
    ACCENT_HEX.fetch(color_key.to_s, "#57534e")
  end

  def mountain_trail_curve_json
    TRAIL_CURVE.to_json
  end

  # Spine polyline for first-camp reveal (base → summit), viewBox 0..100 space.
  def mountain_trail_spine_points
    TRAIL_CURVE.reverse.map { |y, x| [ x.to_f * 100.0, y.to_f * 100.0 ] }
  end

  def mountain_trail_spine_path_d
    mountain_trail_spine_points.map.with_index do |(px, py), index|
      coord = "#{px.round(1)} #{py.round(1)}"
      index.zero? ? "M #{coord}" : "L #{coord}"
    end.join(" ")
  end

  # Arc-length fraction along the spine for a camp at image fractions (trail_x, trail_y).
  def mountain_trail_camp_path_frac(trail_x, trail_y)
    points = mountain_trail_spine_points
    return 0.0 if points.length < 2

    cx = trail_x.to_f * 100.0
    cy = trail_y.to_f * 100.0
    cumulative = [ 0.0 ]
    total = 0.0

    (1...points.length).each do |index|
      dx = points[index][0] - points[index - 1][0]
      dy = points[index][1] - points[index - 1][1]
      total += Math.hypot(dx, dy)
      cumulative << total
    end

    return 0.0 if total.zero?

    best_dist = Float::INFINITY
    best_length = 0.0

    (0...(points.length - 1)).each do |index|
      x0, y0 = points[index]
      x1, y1 = points[index + 1]
      dx = x1 - x0
      dy = y1 - y0
      len2 = (dx * dx) + (dy * dy)
      t = len2.zero? ? 0.0 : (((cx - x0) * dx) + ((cy - y0) * dy)) / len2
      t = t.clamp(0.0, 1.0)
      px = x0 + (t * dx)
      py = y0 + (t * dy)
      dist = ((px - cx)**2) + ((py - cy)**2)
      next unless dist < best_dist

      best_dist = dist
      best_length = cumulative[index] + (t * Math.sqrt(len2))
    end

    (best_length / total).clamp(0.0, 1.0)
  end

  def mountain_trail_projects_by_stage(projects)
    Array(projects).reject { |project| project.try(:holding?) }.group_by { |project| project.try(:stage).to_i }.transform_values do |camps|
      camps.sort_by { |camp| [ camp.try(:position).to_i, camp.try(:id).to_i ] }
    end
  end

  def mountain_trail_open_stage(projects)
    open = Array(projects).reject { |project| project.try(:holding?) || project.try(:completed?) }
    return 0 if open.empty?

    open.map { |project| project.try(:stage).to_i }.min
  end

  def mountain_trail_last_finished_stage(projects)
    by_stage = mountain_trail_projects_by_stage(projects)
    finished = by_stage.keys.select { |stage| mountain_trail_stage_done?(projects, stage) }
    finished.empty? ? nil : finished.max
  end

  def mountain_trail_max_stage(projects)
    stages = Array(projects).reject { |project| project.try(:holding?) }.map { |project| project.try(:stage).to_i }
    stages.empty? ? nil : stages.max
  end

  def mountain_trail_stage_done?(projects, stage)
    camps = mountain_trail_projects_by_stage(projects)[stage.to_i] || []
    return false if camps.empty?

    camps.all? { |camp| camp.try(:completed?) }
  end

  def mountain_trail_stage_label(stage)
    stage.to_i + 1
  end

  def mountain_trail_terrace_range_label(from_stage, to_stage)
    "#{mountain_trail_stage_label(from_stage)}–#{mountain_trail_stage_label(to_stage)}"
  end

  # Four terrace slots bottom→top for the terraced map.
  def mountain_trail_terrace_groups(projects)
    camps = Array(projects).reject { |project| project.try(:holding?) }
    return [] if camps.empty?

    by_stage = mountain_trail_projects_by_stage(camps)
    open_stage = mountain_trail_open_stage(camps)
    last_finished = mountain_trail_last_finished_stage(camps)
    max_stage = mountain_trail_max_stage(camps)
    window = mountain_trail_terrace_window(
      open_stage: open_stage,
      last_finished: last_finished,
      max_stage: max_stage
    )
    foot_badge = mountain_trail_foot_badge(camps, open_stage, last_finished)

    window.each_with_index.map do |slot, index|
      terrace_index = index + 1
      anchor = TERRACE_ANCHORS[terrace_index]
      if slot.nil?
        next {
          index: terrace_index,
          anchor: anchor,
          stage: nil,
          state: :empty,
          camps: [],
          overflow: 0,
          range_label: nil,
          foot_badge: index.zero? ? foot_badge : nil
        }
      end

      if slot.is_a?(Hash) && slot[:range_from]
        from_stage = slot[:range_from]
        {
          index: terrace_index,
          anchor: anchor,
          stage: nil,
          state: :range,
          camps: [],
          overflow: 0,
          range_label: mountain_trail_terrace_range_label(from_stage, max_stage),
          range_from: from_stage,
          range_to: max_stage,
          foot_badge: nil
        }
      else
        stage = slot
        state =
          if stage == open_stage
            :open
          elsif last_finished && stage == last_finished
            :done
          else
            :later
          end
        stage_camps = by_stage[stage] || []
        cap = state == :open ? OPEN_TERRACE_CAMP_CAP : LATER_TERRACE_CAMP_CAP
        visible = stage_camps.first(cap)
        overflow = [ stage_camps.size - visible.size, 0 ].max
        hidden = overflow.positive? ? stage_camps.drop(cap) : []
        {
          index: terrace_index,
          anchor: anchor,
          stage: stage,
          state: state,
          camps: visible,
          hidden_camps: hidden,
          overflow: overflow,
          range_label: nil,
          foot_badge: index.zero? ? foot_badge : nil
        }
      end
    end
  end

  def mountain_trail_terrace_window(open_stage:, last_finished:, max_stage:)
    return [ nil, nil, nil, nil ] if max_stage.nil?

    slots = [ nil, nil, nil, nil ]
    slots[0] = open_stage
    slots[1] = open_stage + 1 if open_stage + 1 <= max_stage
    slots[2] = open_stage + 2 if open_stage + 2 <= max_stage
    if open_stage + 3 <= max_stage
      slots[3] =
        if open_stage + 4 <= max_stage
          { range_from: open_stage + 3 }
        else
          open_stage + 3
        end
    end
    slots
  end

  def mountain_trail_foot_badge(projects, open_stage, last_finished)
    return nil unless last_finished && last_finished < open_stage

    older = (0...open_stage).select { |stage| mountain_trail_stage_done?(projects, stage) }
    return nil if older.empty?

    count = older.sum { |stage| (mountain_trail_projects_by_stage(projects)[stage] || []).size }
    { count: count, stages: older }
  end

  def mountain_trail_terrace_overflow_camps(projects, terrace)
    return Array(terrace[:hidden_camps]) if terrace.key?(:hidden_camps)

    return [] unless terrace[:stage].present? && terrace[:overflow].to_i.positive?

    stage_camps = mountain_trail_projects_by_stage(projects)[terrace[:stage].to_i] || []
    cap = terrace[:state] == :open ? OPEN_TERRACE_CAMP_CAP : LATER_TERRACE_CAMP_CAP
    stage_camps.drop(cap)
  end

  def mountain_trail_terrace_range_entries(projects, terrace)
    return [] unless terrace[:state] == :range && terrace[:range_from]

    by_stage = mountain_trail_projects_by_stage(projects)
    (terrace[:range_from].to_i..terrace[:range_to].to_i).filter_map do |stage|
      camps = by_stage[stage] || []
      next if camps.empty?

      { stage: stage, camps: camps }
    end
  end

  def mountain_trail_terrace_range_aria_label(terrace)
    from = mountain_trail_stage_label(terrace[:range_from])
    to = mountain_trail_stage_label(terrace[:range_to])
    count = terrace[:range_to].to_i - terrace[:range_from].to_i + 1
    I18n.t("strategy.rpg.trail.terrace.range_aria", from: from, to: to, count: count)
  end

  def mountain_trail_terrace_overflow_aria_label(terrace)
    I18n.t(
      "strategy.rpg.trail.terrace.overflow_aria",
      stage: mountain_trail_stage_label(terrace[:stage]),
      count: terrace[:overflow]
    )
  end

  def mountain_trail_terrace_overflow_sheet_for(projects, camp)
    mountain_trail_terrace_groups(projects).each do |terrace|
      hidden = mountain_trail_terrace_overflow_camps(projects, terrace)
      next unless hidden.any? { |candidate| candidate.id == camp.id }

      return {
        sheet_id: "terrace-sheet-overflow-#{terrace[:index]}",
        title: I18n.t(
          "strategy.rpg.trail.terrace.overflow_sheet_title",
          stage: mountain_trail_stage_label(terrace[:stage])
        )
      }
    end
    nil
  end

  def mountain_trail_terrace_debug?
    params[:terrace_debug].to_s == "1"
  end

  def mountain_trail_terrace_size_class(terrace)
    count = terrace[:camps].size
    return "is-solo" if count <= 1
    return "is-pair" if count == 2

    "is-triple"
  end

  # Horizontal delta from terrace centre to slot, as a world-width fraction.
  def mountain_trail_terrace_slot_dx(terrace, slot)
    mountain_trail_terrace_x_fraction(terrace, slot) - terrace[:anchor][:x]
  end

  def mountain_trail_terrace_slot(_camp, terrace, index_in_terrace)
    count = terrace[:camps].size
    if terrace[:state] == :open
      return { slot: :solo, x: :center } if count <= 1

      return { slot: :l, x: :left } if index_in_terrace.zero?

      { slot: :r, x: :right }
    else
      return { slot: :solo, x: :center } if count <= 1

      keys = [ :left, :center, :right ]
      key = keys[index_in_terrace] || :center
      { slot: key, x: key }
    end
  end

  def mountain_trail_terrace_x_fraction(terrace, slot)
    anchor = terrace[:anchor]
    case slot[:x]
    when :left then anchor[:x_left]
    when :right then anchor[:x_right]
    else anchor[:x]
    end
  end

  def mountain_trail_terrace_placed_project_ids(projects, terrace_groups)
    Array(terrace_groups).flat_map do |terrace|
      ids = Array(terrace[:camps]).map(&:id)
      ids.concat(Array(terrace[:hidden_camps]).map(&:id))
      if terrace[:state] == :range
        ids.concat(
          mountain_trail_terrace_range_entries(projects, terrace)
            .flat_map { |entry| entry[:camps].map(&:id) }
        )
      end
      ids
    end.uniq
  end

  def mountain_trail_terrace_fallback_projects(projects, terrace_groups)
    placed = mountain_trail_terrace_placed_project_ids(projects, terrace_groups)
    mountain_trail_sort_projects(Array(projects).reject { |project| project.try(:holding?) })
      .reject { |project| placed.include?(project.id) }
  end

  def mountain_trail_use_terrace_map?(projects, terrace_groups)
    return false if Array(terrace_groups).none?
    return false if Array(terrace_groups).all? { |terrace| terrace[:state] == :empty }

    mountain_trail_terrace_fallback_projects(projects, terrace_groups).empty?
  end

  # Landing order for first-camp reveal: bottom terrace → top.
  def mountain_trail_reveal_camps(projects)
    mountain_trail_terrace_groups(projects).flat_map do |terrace|
      Array(terrace[:camps]).each_with_index.map do |project, slot_index|
        {
          id: project.id,
          terrace_index: terrace[:index],
          slot_index: slot_index,
          delay_ms: ((terrace[:index] - 1) * 400) + (slot_index * 150)
        }
      end
    end
  end

  def mountain_trail_reveal_camps_json(projects)
    mountain_trail_reveal_camps(projects).to_json
  end

  # Segment rail: one bar per camp with fill % and accent.
  def mountain_trail_segments(projects)
    projects.map do |project|
      accent = mountain_trail_project_accent(project)
      pct =
        if project.quantified? && project.target_amount.to_d.positive?
          ((project.current_amount.to_d / project.target_amount.to_d) * 100).clamp(0, 100).round
        else
          days = project.children.select(&:day?).reject(&:holding?)
          if days.empty?
            project.completed? ? 100 : 0
          else
            ((days.count(&:completed?).to_f / days.size) * 100).round
          end
        end
      { id: project.id, color: accent, fill: pct }
    end
  end

  # Tents sit on planted / auto trail coords. No label lift or leader posts.
  def mountain_trail_layout(projects)
    projects.each_with_index.to_h do |project, index|
      slot = mountain_trail_slot(project, index: index, total: projects.size)
      y = slot[:y].to_f.round(4)
      x = slot[:x].to_f.round(4)
      [ project.id, {
        project: project,
        x: x,
        y: y,
        anchor_y: y,
        label_y: y,
        leader_h: 0,
        placed: slot[:placed]
      } ]
    end
  end

  def mountain_trail_camp_shadow(layout, light_x: PEAK_X)
    dx = ((layout[:x].to_f - light_x.to_f) * 0.12).clamp(-0.04, 0.04)
    y = layout[:y].to_f
    stretch = 1.0 + (0.62 - y) * 0.2
    {
      dx: dx.round(4),
      width: (0.024 + (stretch - 1) * 0.014).round(4),
      opacity: (0.28 + (1 - y) * 0.1).round(3)
    }
  end

  def mountain_trail_plant_starters
    PLANT_ICON_STARTERS.map do |entry|
      entry.merge(
        label: I18n.t("strategy.rpg.trail.icon_starters.#{entry[:key]}")
      )
    end
  end

  def mountain_trail_battle_suggestion(project)
    journey = project.life_journey
    category =
      if journey
        Onboarding::Categories.id_for_journey(journey)
      else
        "other"
      end
    list = Array(I18n.t("strategy.rpg.trail.battle_suggestions", default: []))
    if journey
      list += Array(I18n.t("strategy.first_climb.examples.#{category}.action", default: []))
    end
    list = list.uniq
    return nil if list.empty?

    list[project.id % list.size]
  end

  def mountain_trail_last_log_amount(project)
    return nil if project.blank?

    project.strategy_quantity_logs.order(logged_on: :desc, id: :desc).limit(1).pick(:amount)
  end

  def mountain_trail_layout_slot(project, projects:)
    layout = mountain_trail_layout(projects)
    layout[project.id] || begin
      slot = mountain_trail_slot(project, index: 0, total: [ projects.size, 1 ].max)
      { x: slot[:x], y: slot[:y], anchor_y: slot[:y], label_y: slot[:y], leader_h: 0 }
    end
  end

  # Current camp: lowest open stage with an open battle, then position.
  def mountain_trail_current_project(projects)
    eligible = projects.reject(&:completed?).reject(&:pages_mode?).select do |project|
      project.children.any? { |c| c.day? && !c.holding? && !c.completed? }
    end

    mountain_trail_pick_by_stage(eligible)
  end

  def mountain_trail_first_open_battle(project)
    project.children
      .select { |c| c.day? && !c.holding? && !c.completed? }
      .min_by { |c| [ c.position.to_i, c.id ] }
  end

  def mountain_trail_fire_level(project)
    return 0 if project.completed? || project.pages_mode?

    total = project.children.count { |c| c.day? && !c.holding? }
    return 2 if total >= 6
    return 1 if total >= 3

    0
  end

  def mountain_trail_camp_state(project, projects:)
    return :done if project.completed?

    next_camp = mountain_trail_next_camp(projects)
    next_camp&.id == project.id ? :current : :open
  end

  def mountain_trail_camp_label(project)
    mountain_trail_camp_status(project)
  end

  def mountain_trail_camp_caption_title(project)
    project.title.to_s.truncate(CAMP_TENT_TITLE_LIMIT)
  end

  def mountain_trail_camp_sheet_title(project)
    title = project.title.to_s
    prefix = I18n.t("strategy.first_climb.project_title", plan: "")
    title.delete_prefix(prefix)
  end

  def mountain_trail_hud_plan_title(title)
    title.to_s.truncate(HUD_PLAN_TITLE_LIMIT)
  end

  def mountain_trail_camp_days(project)
    Array(project&.children).select { |child| child.day? && !child.holding? }
  end

  # Preload today's DailyTodos for Mountain camp rows (one query per render surface).
  def mountain_trail_preload_done_today!(user, battles)
    ids = Array(battles).filter_map(&:id)
    @mountain_done_today_by_goal_id =
      if ids.empty? || user.blank?
        {}
      else
        user.daily_todos.for_day.where(strategy_goal_id: ids).index_by(&:strategy_goal_id)
      end
  end

  # Mountain camp "won" read model: one-shots use completed_at; dailies use today's todo.
  # Camp progress counts are today-scoped for dailies (not lifetime-cleared).
  def mountain_trail_done_today?(battle, user: nil)
    return false if battle.blank?
    unless battle.try(:repeat_recurring?)
      return battle.completed_at.present? if battle.respond_to?(:completed_at)
      return battle.completed? if battle.respond_to?(:completed?)

      return false
    end

    viewer = user || mountain_trail_viewer
    return false if viewer.blank?

    todo = @mountain_done_today_by_goal_id&.dig(battle.id) ||
           viewer.daily_todos.for_day.find_by(strategy_goal_id: battle.id)
    todo&.completed_at.present?
  end

  # Calendar-today wins only — for idle State B copy. Does not affect open_battles.
  def mountain_trail_won_today?(battle, user: nil)
    return false if battle.blank?

    if battle.try(:repeat_recurring?)
      viewer = user || mountain_trail_viewer
      return false if viewer.blank?

      todo = @mountain_done_today_by_goal_id&.dig(battle.id) ||
             viewer.daily_todos.for_day.find_by(strategy_goal_id: battle.id)
      return todo&.completed_at.present?
    end

    return false unless battle.respond_to?(:completed_at) && battle.completed_at.present?

    battle.completed_at.in_time_zone(Time.zone).to_date == Date.current
  end

  def mountain_trail_camp_progress(project, user: nil)
    if project&.pages_mode? || (project&.quantified? && mountain_trail_camp_days(project).empty?)
      meta = strategy_project_card_meta(project)
      ratio = meta&.dig(:ratio).to_f
      return { kind: :pages, ratio: ratio.clamp(0, 1), open: 0, won: 0, total: 0 }
    end

    days = mountain_trail_camp_days(project).select { |day| mountain_trail_camp_due?(day) }
    total = days.size
    viewer = user || mountain_trail_viewer
    won = days.count { |day| mountain_trail_done_today?(day, user: viewer) }
    open = total - won
    ratio = total.zero? ? 0.0 : (won.to_f / total)
    { kind: :battles, ratio: ratio, open: open, won: won, total: total }
  end

  def mountain_trail_camp_status(project)
    progress = mountain_trail_camp_progress(project)
    if progress[:kind] == :pages
      return strategy_quantity_progress_label(project).presence || I18n.t("strategy.rpg.trail.camp_status.empty")
    end

    if progress[:total].zero?
      I18n.t("strategy.rpg.trail.camp_status.empty")
    elsif progress[:open].zero?
      I18n.t("strategy.rpg.trail.camp_status.cleared")
    else
      I18n.t("strategy.rpg.trail.camp_status.ready", count: progress[:open])
    end
  end

  def mountain_trail_spur_d(x, y)
    tent_x = x.to_f
    tent_y = y.to_f
    spine = AutoSlot.snap(tent_x, tent_y)
    sx = (spine[:trail_x] * 100).round(2)
    sy = (spine[:trail_y] * 100).round(2)
    tx = (tent_x * 100).round(2)
    ty = (tent_y * 100).round(2)
    cx = ((sx + tx) / 2.0).round(2)
    cy = (((sy + ty) / 2.0) - 1.2).round(2)
    "M#{sx} #{sy} Q #{cx} #{cy} #{tx} #{ty}"
  end

  def mountain_trail_base_habits(journey:, user: current_user)
    return [] if journey.blank? || user.blank?

    mountain_trail_journey_habits(journey: journey, user: user)
      .includes(:daily_logs, :completions)
      .to_a
  end

  def mountain_trail_base_pills(journey:, projects:, user: current_user)
    items = []
    if GameRules.habits_enabled? && user && journey
      habits = mountain_trail_journey_habits(journey: journey, user: user)
      items = habits.limit(4).map { |habit|
        count = if habit.association(:completions).loaded?
          habit.completions.size
        else
          habit.completions.count
        end
        { name: habit.name, count: count }
      }
    end

    if items.empty?
      dailies = Array(projects).flat_map { |project|
        mountain_trail_camp_days(project).select { |battle| mountain_trail_base_due?(battle) }
      }
      items = dailies.first(4).map { |battle|
        started = battle.created_at&.to_date || Date.current
        { name: battle.title, count: (Date.current - started).to_i + 1 }
      }
    end

    { items: items.first(3), extra: [ items.size - 3, 0 ].max }
  end

  def mountain_trail_sort_projects(projects)
    Array(projects).sort_by { |project| [ project.position.to_i, project.id ] }
  end

  # Next camp on the open ledge: lowest stage, then position.
  def mountain_trail_next_camp(projects)
    mountain_trail_pick_by_stage(
      Array(projects).reject(&:completed?).reject(&:pages_mode?).reject(&:holding?)
    )
  end

  def mountain_trail_open_camps(plan)
    mountain_trail_sort_projects(
      Array(plan&.children).select { |child| child.project? && !child.holding? && !child.completed? }
    )
  end

  # Parent for base-camp daily creates — matches is-current marker, then idle camp.
  def mountain_trail_base_camp_add_parent(projects)
    ordered = mountain_trail_sort_projects(projects)
    mountain_trail_current_project(ordered) ||
      mountain_trail_idle_camp(ordered) ||
      ordered.find { |project| !project.pages_mode? } ||
      ordered.first
  end

  def mountain_trail_daily_battles(projects)
    Array(projects).filter_map { |project|
      battles = mountain_trail_camp_days(project).select { |battle| mountain_trail_base_due?(battle) }
      next if battles.empty?

      { project: project, battles: battles }
    }
  end

  # Flat due list — same rows as the Base camp sheet (for dock today_card).
  def mountain_trail_base_due_battles(projects)
    mountain_trail_daily_battles(projects).flat_map { |group| group[:battles] }
  end

  # Short weekday chip for weekly battles (e.g. "M W F"). Nil unless repeat_weekly?.
  def mountain_trail_repeat_weekday_chip(battle)
    return unless battle.try(:repeat_weekly?)

    weekdays = battle.repeat_weekdays_array
    return if weekdays.empty?

    abbr = I18n.t("date.abbr_day_names")
    full = I18n.t("date.day_names")
    {
      label: weekdays.map { |wday| abbr[wday].first }.join(" "),
      aria_label: weekdays.map { |wday| full[wday] }.join(", ")
    }
  end

  # Camp sheet open list + progress: weekly rows only on scheduled weekdays; daily/one-shot unchanged.
  def mountain_trail_camp_due?(battle)
    return false if battle.blank?
    return mountain_trail_base_due?(battle) if battle.try(:repeat_weekly?)

    true
  end

  # Daily template still due today (scheduled_on moves to tomorrow after a win).
  def mountain_trail_base_due?(battle)
    return false unless battle.try(:repeat_daily?) || battle.try(:repeat_weekly?)
    return false if battle.respond_to?(:completed?) && battle.completed?
    return false if battle.respond_to?(:completed_at) && battle.completed_at.present? && !battle.try(:repeat_recurring?)
    return false if battle.scheduled_on.present? && battle.scheduled_on > Date.current
    return false if battle.try(:repeat_weekly?) && !battle.repeats_on?(Date.current)

    true
  end

  def mountain_trail_camps_done(projects)
    projects.count(&:completed?)
  end

  def mountain_trail_dormant?(projects)
    projects.none? do |project|
      project.children.any? { |c| c.day? && !c.holding? && !c.completed? }
    end
  end

  # Climb day shown on the base-camp pill ("Base camp · Day N").
  def mountain_trail_day_count(journey)
    return 1 if journey.blank?

    start_on = journey.created_at.to_date
    (Date.current - start_on).to_i + 1
  end

  # Lowest-stage incomplete camp with no battles yet — meadow “add a battle” target.
  def mountain_trail_idle_camp(projects)
    idle = Array(projects).reject(&:completed?).reject(&:pages_mode?).select do |project|
      project.children.none? { |child| child.day? && !child.holding? }
    end

    mountain_trail_pick_by_stage(idle)
  end

  # Meadow plaque: one next step, or a short win.
  # open_battles: due daily rows (mountain_trail_base_due_battles), not @today_battles.
  def mountain_trail_today_card(projects: [], open_battles: [], won_today: 0, journey: nil, user: nil)
    camps = Array(projects)
    waiting = Array(open_battles).select { |battle| battle.try(:completed_at).blank? }

    if camps.empty?
      return meadow_plaque(
        mode: "plant_first",
        headline: I18n.t("strategy.rpg.trail.today_card.plant_first_headline"),
        sub: I18n.t("strategy.rpg.trail.today_card.plant_first_sub")
      )
    end

    next_battle = waiting.first
    if next_battle
      return meadow_plaque(
        mode: "win_next",
        headline: I18n.t("strategy.rpg.trail.today_card.win_headline", count: waiting.size),
        sub: I18n.t("strategy.rpg.trail.today_card.win_sub"),
        count: waiting.size,
        busy: true
      )
    end

    viewer = user || mountain_trail_viewer
    if journey.present? && viewer.present? &&
         mountain_trail_base_habits(journey: journey, user: viewer).any?
      return meadow_plaque(
        mode: "basics",
        headline: I18n.t("strategy.rpg.trail.base_camp.title"),
        sub: I18n.t("strategy.rpg.trail.today_card.basics_sub"),
        busy: true
      )
    end

    idle = mountain_trail_idle_camp(camps)
    if idle
      return meadow_plaque(
        mode: "add_battle",
        headline: I18n.t("strategy.rpg.trail.today_card.add_headline"),
        sub: I18n.t("strategy.rpg.trail.today_card.add_sub", camp: idle.title),
        busy: true,
        camp_id: idle.id
      )
    end

    if won_today.to_i.positive?
      return meadow_plaque(
        mode: "cheer",
        headline: I18n.t("strategy.rpg.trail.today_card.cheer_headline"),
        sub: I18n.t("strategy.rpg.trail.today_card.cheer_sub", count: won_today),
        count: won_today
      )
    end

    meadow_plaque(
      mode: "plant_next",
      headline: I18n.t("strategy.rpg.trail.today_card.plant_next_headline"),
      sub: I18n.t("strategy.rpg.trail.today_card.plant_next_sub")
    )
  end

  def meadow_plaque(mode:, headline:, sub:, count: 0, badge: false, busy: false, camp_id: nil)
    { mode: mode, headline: headline, sub: sub, count: count, badge: badge, busy: busy, camp_id: camp_id }
  end
  private :meadow_plaque

  def mountain_trail_peak_tagline(goal)
    goal&.description.to_s.strip.presence ||
      I18n.t("strategy.rpg.trail.peak_tagline_default")
  end

  # Fraction of climb behind the companion (camps completed / total).
  def mountain_trail_climb_fraction(projects)
    total = projects.size
    return 0.0 if total <= 0

    mountain_trail_camps_done(projects).to_f / total
  end

  # Point on the traced trail curve for a y-fraction (0..1 down the photo).
  def mountain_trail_point_on_curve(y_frac)
    y = y_frac.to_f.clamp(TRAIL_CURVE.first[0], TRAIL_CURVE.last[0])
    { x: AutoSlot.x_for(y), y: y }
  end

  # Footprint dots from base up to the companion climb fraction.
  def mountain_trail_footprints(projects, count: 8)
    frac = mountain_trail_climb_fraction(projects)
    return [] if frac <= 0.02

    end_y = FOOT_BASE_Y - frac * (FOOT_BASE_Y - FOOT_TOP_Y)
    steps = [ (count * frac).ceil, 1 ].max
    (0...steps).map do |i|
      t = (i + 1).to_f / steps
      y = FOOT_BASE_Y - t * (FOOT_BASE_Y - end_y)
      point = mountain_trail_point_on_curve(y)
      point.merge(opacity: (0.25 + t * 0.55).round(2))
    end
  end

  def mountain_trail_companion_slot(projects)
    marker = mountain_trail_climber_marker(projects)
    return marker.slice(:x, :y) if marker[:visible]

    mountain_trail_point_on_curve(BASE_YFRAC)
  end

  # Display-only climber on the trail spine between last cleared camp and focus camp.
  def mountain_trail_climber_marker(all_projects, user: nil)
    camps = Array(all_projects).reject(&:holding?)
    return { visible: false } if camps.empty?

    focus = mountain_trail_focus_camp(camps)
    return { visible: false } if focus.blank?

    progress = mountain_trail_camp_progress(focus, user: user || mountain_trail_viewer)
    display_ratio = mountain_trail_climber_display_ratio(progress)

    layout = mountain_trail_layout(camps)
    focus_layout = layout[focus.id]
    return { visible: false } if focus_layout.blank?

    focus_y = focus_layout[:y].to_f
    completed = camps.select(&:completed?)
    last_cleared = completed
      .select { |project| layout[project.id] && layout[project.id][:y].to_f > focus_y }
      .min_by { |project| layout[project.id][:y].to_f }

    from_y = last_cleared ? layout[last_cleared.id][:y].to_f : BASE_YFRAC
    to_y = focus_y
    y = from_y - (display_ratio * (from_y - to_y))
    point = mountain_trail_point_on_curve(y)

    {
      visible: true,
      x: point[:x],
      y: point[:y],
      ratio: display_ratio
    }
  end

  def mountain_trail_climber_display_ratio(progress)
    ratio = progress[:ratio].to_f.clamp(0.0, 1.0)
    return ratio unless progress[:kind] == :battles

    won = progress[:won].to_i
    total = progress[:total].to_i
    return 0.0 if won <= 0 || total <= 0

    raw = won.to_f / total
    stepped = won * CLIMBER_MIN_LEG_STEP
    [ raw, stepped ].max.clamp(0.0, 1.0)
  end

  # Focus camp for the climber: open battles, idle camp, or lowest-stage working camp.
  def mountain_trail_focus_camp(projects)
    current = mountain_trail_current_project(projects)
    return current if current

    idle = mountain_trail_idle_camp(projects)
    return idle if idle

    working = Array(projects).reject(&:completed?).reject(&:pages_mode?).select do |project|
      project.children.any? { |child| child.day? && !child.holding? }
    end

    mountain_trail_pick_by_stage(working)
  end

  # Momentum 0..1 for embers / hero saturation (mockup energy).
  def mountain_trail_energy(projects)
    open = projects.sum { |p| p.children.count { |c| c.day? && !c.holding? && !c.completed? } }
    won = projects.sum { |p| p.children.count { |c| c.day? && !c.holding? && c.completed? } }
    total = projects.sum { |p| p.children.count { |c| c.day? && !c.holding? } }
    [ (won * 0.5 + total * 0.15) / 6.0, 1.0 ].min + (open.positive? ? 0.05 : 0)
  end

  def mountain_trail_pick_by_stage(projects)
    list = Array(projects).compact
    return if list.empty?

    open_stage = list.map { |project| project.try(:stage).to_i }.min
    in_stage = list.select { |project| project.try(:stage).to_i == open_stage }
    in_stage.min_by { |project| [ project.position.to_i, project.id ] }
  end

  def mountain_trail_viewer
    current_user if respond_to?(:current_user)
  end
  private :mountain_trail_viewer, :mountain_trail_pick_by_stage

  def mountain_trail_journey_habits(journey:, user:)
    return user.habits.none if journey.blank? || user.blank?

    user.habits.active.ordered.where(
      "life_journey_id = ? OR area_id = ?",
      journey.id,
      journey.life_area_id
    )
  end
  private :mountain_trail_journey_habits
end
