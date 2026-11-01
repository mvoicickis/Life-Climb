# frozen_string_literal: true

module WorldsHelper
  # Me disk outer edge, then three thick annuli. Gap between bands.
  WORLD_BAND_OUTERS = [ 40, 74, 108, 138 ].freeze
  WORLD_BAND_GAP = 3

  # Thin-orbit midpoints kept for any non-band callers.
  WORLD_ORBIT_RADII = [ 50, 94, 138 ].freeze

  # All-time wins on a ring → fill step 0..4.
  def self.win_step(wins)
    w = wins.to_i
    return 0 if w <= 0
    return 1 if w == 1
    return 2 if w <= 10
    return 3 if w <= 50

    4
  end

  def my_world_win_step(wins)
    WorldsHelper.win_step(wins)
  end

  # Day-cell shade for the 7-day strip: 0 / 1 / 2–3 / 4+.
  def self.day_cell_step(day_wins)
    w = day_wins.to_i
    return 0 if w <= 0
    return 1 if w == 1
    return 2 if w <= 3

    4
  end

  def my_world_day_cell_step(day_wins)
    WorldsHelper.day_cell_step(day_wins)
  end

  def my_world_day_cell_background(color_index, day_wins)
    step = WorldsHelper.day_cell_step(day_wins)
    return "var(--lp-border)" if step.zero?

    my_world_step_token(color_index, step)
  end

  def my_world_weekday_letter(date)
    name = I18n.t("date.abbr_day_names")[date.wday].to_s
    name[0]
  end


  def my_world_orbit_radius(ring)
    index = LifeArea::WORLD_RINGS.index(ring.to_s)
    return nil if index.nil? || index.zero?

    WORLD_ORBIT_RADII[index - 1]
  end

  # Geometry for a thick outer band (not Me). mid = stroke radius; outer for the flag.
  def my_world_band_geometry(ring)
    index = LifeArea::WORLD_RINGS.index(ring.to_s)
    return nil if index.nil? || index.zero?

    r_outer = WORLD_BAND_OUTERS[index]
    r_inner = WORLD_BAND_OUTERS[index - 1]
    {
      mid: (r_inner + r_outer) / 2.0,
      outer: r_outer.to_f,
      stroke_full: [ r_outer - r_inner - WORLD_BAND_GAP, 2 ].max.to_f
    }
  end

  def my_world_step_token(color_index, step)
    "var(--lp-world-#{color_index}-#{step})"
  end

  def my_world_ring_token(color_index)
    "var(--lp-world-#{color_index})"
  end

  # ~16px ink flag on the outer edge (top-right).
  def my_world_finished_flag(r_outer)
    ang = -Math::PI / 4
    x = 140 + r_outer * Math.cos(ang)
    y = 140 + r_outer * Math.sin(ang)
    tag.g(class: "lp-my-world-rings__flag", transform: "translate(#{format("%.2f", x)} #{format("%.2f", y)})") do
      tag.path(
        d: "M0 6 V-16 M0 -16 L14 -9 L0 -2 Z",
        fill: "var(--lp-ink)",
        stroke: "var(--lp-ink)",
        "stroke-width": "1.6",
        "stroke-linejoin": "round"
      )
    end
  end

  def my_world_ring_icon(ring)
    icons = {
      "me" => <<~SVG,
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><circle cx="12" cy="8" r="3"/><path d="M6.5 19c1.2-3 3.2-4.5 5.5-4.5s4.3 1.5 5.5 4.5"/></svg>
      SVG
      "family_friends" => <<~SVG,
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><path d="M12 20s-7-4.2-7-9.2A3.8 3.8 0 0 1 12 8a3.8 3.8 0 0 1 7 2.8C19 15.8 12 20 12 20z"/></svg>
      SVG
      "work_money" => <<~SVG,
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><rect x="4" y="7" width="16" height="12" rx="1.5"/><path d="M8 7V5.5A2.5 2.5 0 0 1 10.5 3h3A2.5 2.5 0 0 1 16 5.5V7"/><path d="M4 12h16"/></svg>
      SVG
      "creativity" => <<~SVG
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M9 18V7.5A2.5 2.5 0 0 1 11.5 5H14"/><circle cx="7.5" cy="18" r="2"/><circle cx="16.5" cy="16" r="2"/><path d="M14 5v9"/></svg>
      SVG
    }
    icons.fetch(ring.to_s, "").html_safe
  end
end
