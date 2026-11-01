# frozen_string_literal: true

module WorldsHelper
  # Three outer orbits, evenly spaced; outermost matches the previous outer ring.
  WORLD_ORBIT_RADII = [ 50, 94, 138 ].freeze

  def my_world_orbit_radius(ring)
    index = LifeArea::WORLD_RINGS.index(ring.to_s)
    return nil if index.nil? || index.zero?

    WORLD_ORBIT_RADII[index - 1]
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
