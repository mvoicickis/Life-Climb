# frozen_string_literal: true

module WorldsHelper
  WORLD_ORBIT_RADII = [ 44, 60, 76, 92, 108, 124, 138 ].freeze

  def my_world_orbit_radius(ring)
    index = LifeArea::WORLD_RINGS.index(ring.to_s)
    return nil if index.nil? || index.zero?

    WORLD_ORBIT_RADII[index - 1]
  end

  def my_world_ring_icon(ring)
    icons = {
      "me" => <<~SVG,
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true"><circle cx="12" cy="8" r="3"/><path d="M6.5 19c1.2-3 3.2-4.5 5.5-4.5s4.3 1.5 5.5 4.5"/></svg>
      SVG
      "family_love" => <<~SVG,
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true"><path d="M12 20s-7-4.2-7-9.2A3.8 3.8 0 0 1 12 8a3.8 3.8 0 0 1 7 2.8C19 15.8 12 20 12 20z"/></svg>
      SVG
      "friends_work" => <<~SVG,
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true"><circle cx="8" cy="10" r="2.2"/><circle cx="16" cy="10" r="2.2"/><path d="M4.5 18c.8-2.2 2.2-3.3 3.5-3.3S10.7 15.8 11.5 18M12.5 18c.8-2.2 2.2-3.3 3.5-3.3s2.7 1.1 3.5 3.3"/></svg>
      SVG
      "people" => <<~SVG,
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true"><circle cx="12" cy="8" r="2.4"/><circle cx="6.5" cy="11" r="2"/><circle cx="17.5" cy="11" r="2"/><path d="M5 19c.7-2 1.9-3 3.2-3 .9 0 1.7.4 2.4 1.1M19 19c-.7-2-1.9-3-3.2-3-.9 0-1.7.4-2.4 1.1M10.2 17.1c.5-1.2 1.3-1.8 1.8-1.8s1.3.6 1.8 1.8"/></svg>
      SVG
      "animals_nature" => <<~SVG,
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true"><path d="M12 19V11"/><path d="M8 19h8"/><path d="M12 11c-2.5 0-4-1.8-4-4 1.8.2 3 .9 4 2 1-1.1 2.2-1.8 4-2 0 2.2-1.5 4-4 4z"/></svg>
      SVG
      "things_money" => <<~SVG,
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true"><rect x="4" y="9" width="16" height="10" rx="1.5"/><path d="M8 9V7a4 4 0 0 1 8 0v2"/></svg>
      SVG
      "spirit" => <<~SVG,
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true"><circle cx="12" cy="12" r="3"/><path d="M12 3v2.5M12 18.5V21M4.9 4.9l1.8 1.8M17.3 17.3l1.8 1.8M3 12h2.5M18.5 12H21M4.9 19.1l1.8-1.8M17.3 6.7l1.8-1.8"/></svg>
      SVG
      "infinity" => <<~SVG
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true"><path d="M5 12c2.5-4 5-6 7-6s4.5 2 7 6c-2.5 4-5 6-7 6s-4.5-2-7-6z"/><circle cx="12" cy="12" r="2"/></svg>
      SVG
    }
    icons.fetch(ring.to_s, "").html_safe
  end
end
