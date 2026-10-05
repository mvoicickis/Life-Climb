# frozen_string_literal: true

module TurboStreamActionsHelper
  def open_trail_camp(camp_id)
    turbo_stream_action_tag :open_trail_camp, target: "mountain-trail", "camp-id": camp_id
  end

  def update_mountain_trail_root(summit_reached:, dormant:, summit_glow:, climb_frac:, trail_energy:)
    turbo_stream_action_tag :update_mountain_trail_root,
                            target: "mountain-trail",
                            summit_reached: summit_reached ? "true" : "false",
                            dormant: dormant ? "true" : "false",
                            summit_glow: summit_glow.to_s,
                            climb_frac: climb_frac.to_s,
                            trail_energy: trail_energy.to_s
  end
end

Turbo::Streams::TagBuilder.prepend(TurboStreamActionsHelper)
