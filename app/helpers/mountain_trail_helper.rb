# frozen_string_literal: true

# Places path projects on the Mountain V4 photo trail.
# Coordinates are fractions: x across the canvas, y down from the peak.
module MountainTrailHelper
  # Traced path on the default 1024×1536 mountain photo (yFrac, xFrac).
  TRAIL_CURVE = [
    [ 0.28, 0.525 ], [ 0.29, 0.526 ], [ 0.30, 0.548 ], [ 0.31, 0.570 ], [ 0.32, 0.582 ],
    [ 0.33, 0.572 ], [ 0.34, 0.553 ], [ 0.35, 0.560 ], [ 0.36, 0.584 ], [ 0.37, 0.589 ],
    [ 0.38, 0.572 ], [ 0.39, 0.553 ], [ 0.40, 0.535 ], [ 0.41, 0.553 ], [ 0.42, 0.564 ],
    [ 0.43, 0.578 ], [ 0.44, 0.567 ], [ 0.45, 0.537 ], [ 0.46, 0.503 ], [ 0.47, 0.477 ],
    [ 0.48, 0.483 ], [ 0.49, 0.545 ], [ 0.50, 0.573 ], [ 0.51, 0.585 ], [ 0.52, 0.570 ],
    [ 0.53, 0.528 ], [ 0.54, 0.493 ], [ 0.55, 0.463 ], [ 0.56, 0.472 ], [ 0.57, 0.517 ],
    [ 0.58, 0.563 ], [ 0.59, 0.585 ], [ 0.60, 0.588 ], [ 0.61, 0.565 ], [ 0.62, 0.531 ],
    [ 0.63, 0.500 ], [ 0.64, 0.476 ], [ 0.65, 0.479 ], [ 0.66, 0.497 ], [ 0.67, 0.498 ],
    [ 0.68, 0.563 ], [ 0.69, 0.595 ], [ 0.70, 0.606 ], [ 0.71, 0.593 ], [ 0.72, 0.567 ],
    [ 0.73, 0.532 ], [ 0.74, 0.503 ], [ 0.75, 0.535 ], [ 0.76, 0.578 ], [ 0.77, 0.578 ],
    [ 0.78, 0.582 ], [ 0.79, 0.598 ], [ 0.80, 0.618 ], [ 0.81, 0.618 ], [ 0.82, 0.601 ],
    [ 0.83, 0.575 ], [ 0.84, 0.532 ], [ 0.85, 0.509 ], [ 0.86, 0.496 ], [ 0.87, 0.458 ],
    [ 0.88, 0.440 ], [ 0.89, 0.411 ], [ 0.90, 0.412 ], [ 0.91, 0.433 ], [ 0.92, 0.446 ],
    [ 0.93, 0.451 ], [ 0.94, 0.487 ], [ 0.95, 0.502 ]
  ].freeze

  TRAIL_Y_MIN = 0.32
  TRAIL_Y_MAX = 0.88
  PEAK_X = 0.566
  # Default photo summit (baked-in flag tip on mountain_trail_default ≈ 0.22).
  PEAK_Y = 0.22

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
  SIGN_MIN_GAP = 0.09
  SIGN_FLOOR_Y = 0.72
  PEAK_BAND_Y = 0.26
  GHOST_HEIGHT = 0.055
  SIGN_HEIGHT = 0.088
  GHOST_MIN_SPAN = SIGN_HEIGHT + GHOST_HEIGHT + 0.012
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
      image_path("mountain_trail_default.webp")
    end
  rescue StandardError
    if journey&.mountain_photo&.attached?
      url_for(journey.mountain_photo)
    else
      image_path("mountain_trail_default.webp")
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

  def mountain_trail_ghosts(projects, layout: nil, current_project: nil)
    if projects.empty?
      return [ { x: AutoSlot.x_for(0.55), y: 0.55 } ]
    end

    layout ||= mountain_trail_layout(projects)
    occupied = projects.filter_map { |p| layout.dig(p.id, :y)&.to_f }.sort
    blocked = [ PEAK_BAND_Y + 0.04 ]
    if current_project && layout[current_project.id]
      camp_y = layout[current_project.id][:y].to_f
      blocked.concat([ camp_y + 0.035, camp_y + 0.08 ])
    end

    bounds = [ PEAK_BAND_Y ].concat(occupied).concat(blocked).concat([ SIGN_FLOOR_Y ]).sort.uniq
    gaps = []
    bounds.each_cons(2) do |low, high|
      span = high - low
      bottom = low + GHOST_HEIGHT + 0.012
      next unless span > GHOST_MIN_SPAN
      next unless bottom <= high - SIGN_HEIGHT - 0.012

      gaps << { y: bottom, span: span }
    end

    gaps.sort_by { |g| -g[:span] }.first(projects.size >= 2 ? 2 : 3).map do |g|
      { x: AutoSlot.x_for(g[:y]), y: g[:y].clamp(TRAIL_Y_MIN, TRAIL_Y_MAX) }
    end
  end

  def mountain_trail_curve_json
    TRAIL_CURVE.to_json
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

  # Current camp: lowest on trail (highest y) with an open battle — mockup Duolingo node.
  def mountain_trail_current_project(projects)
    eligible = projects.reject(&:completed?).reject(&:pages_mode?).select do |project|
      project.children.any? { |c| c.day? && !c.holding? && !c.completed? }
    end
    return nil if eligible.empty?

    layout = mountain_trail_layout(projects)
    eligible.max_by { |p| layout.dig(p.id, :y).to_f }
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

    current = mountain_trail_current_project(projects)
    current&.id == project.id ? :current : :open
  end

  def mountain_trail_camp_label(project)
    mountain_trail_camp_status(project)
  end

  def mountain_trail_camp_days(project)
    Array(project&.children).select { |child| child.day? && !child.holding? }
  end

  def mountain_trail_camp_progress(project)
    if project&.pages_mode? || (project&.quantified? && mountain_trail_camp_days(project).empty?)
      meta = strategy_project_card_meta(project)
      ratio = meta&.dig(:ratio).to_f
      return { kind: :pages, ratio: ratio.clamp(0, 1), open: 0, won: 0, total: 0 }
    end

    days = mountain_trail_camp_days(project)
    total = days.size
    won = days.count(&:completed?)
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

  def mountain_trail_base_pills(journey:, projects:, user: current_user)
    items = []
    if GameRules.habits_enabled? && user && journey
      habits = user.habits.active.ordered
      habits = habits.select { |habit|
        habit.life_journey_id == journey.id || habit.area_id == journey.life_area_id
      }
      items = habits.first(4).map { |habit|
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
        mountain_trail_camp_days(project).select { |battle| battle.repeat_daily? && !battle.completed? }
      }
      items = dailies.first(4).map { |battle|
        started = battle.created_at&.to_date || Date.current
        { name: battle.title, count: (Date.current - started).to_i + 1 }
      }
    end

    { items: items.first(3), extra: [ items.size - 3, 0 ].max }
  end

  def mountain_trail_daily_battles(projects)
    Array(projects).filter_map { |project|
      battles = mountain_trail_camp_days(project).select { |battle| battle.repeat_daily? && !battle.completed? }
      next if battles.empty?

      { project: project, battles: battles }
    }
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

  # Lowest incomplete camp with no battles yet — meadow “add a battle” target.
  def mountain_trail_idle_camp(projects)
    idle = Array(projects).reject(&:completed?).reject(&:pages_mode?).select do |project|
      project.children.none? { |child| child.day? && !child.holding? }
    end
    return if idle.empty?

    layout = mountain_trail_layout(projects)
    idle.max_by { |project| layout.dig(project.id, :y).to_f }
  end

  # Meadow plaque: one next step, or a short win.
  def mountain_trail_today_card(projects: [], open_battles: [], won_today: 0)
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
    current = mountain_trail_current_project(projects)
    if current
      layout = mountain_trail_layout(projects)
      slot = layout[current.id]
      return { x: slot[:x], y: [ slot[:y] + 0.035, 0.91 ].min } if slot
    end

    frac = mountain_trail_climb_fraction(projects)
    y = FOOT_BASE_Y - frac * (FOOT_BASE_Y - FOOT_TOP_Y)
    mountain_trail_point_on_curve(y)
  end

  # Momentum 0..1 for embers / hero saturation (mockup energy).
  def mountain_trail_energy(projects)
    open = projects.sum { |p| p.children.count { |c| c.day? && !c.holding? && !c.completed? } }
    won = projects.sum { |p| p.children.count { |c| c.day? && !c.holding? && c.completed? } }
    total = projects.sum { |p| p.children.count { |c| c.day? && !c.holding? } }
    [ (won * 0.5 + total * 0.15) / 6.0, 1.0 ].min + (open.positive? ? 0.05 : 0)
  end
end
