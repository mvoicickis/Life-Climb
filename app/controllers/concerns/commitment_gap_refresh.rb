# frozen_string_literal: true

# Reloads NextAction + commitment context for turbo-stream panel replaces.
module CommitmentGapRefresh
  extend ActiveSupport::Concern

  private

  def refresh_commitment_gap_context!(open_reveal: nil)
    @journey = current_user.primary_focused_journey
    @commitment = Today::Commitment.progress(user: current_user, journey: @journey)
    @next_action = Strategy::NextAction.for(
      user: current_user,
      session: session,
      journey: @journey
    )
    @open_reveal = open_reveal.to_s.presence
    @planned_battles = current_user.daily_todos.for_day(Date.current).incomplete.ordered.to_a
  end

  def render_commitment_gap_stream
    render template: "shared/commitment_gap_refresh", formats: [ :turbo_stream ]
  end
end
