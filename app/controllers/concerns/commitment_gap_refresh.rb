# frozen_string_literal: true

# Reloads NextAction + commitment + Today battle surface for turbo-stream replaces.
module CommitmentGapRefresh
  extend ActiveSupport::Concern

  include Dashboard::TodaySurface

  private

  def refresh_commitment_gap_context!(open_reveal: nil, gap_notice: nil)
    @journey = current_user.primary_focused_journey
    assign_today_battle_surface!(reconcile: false) if @journey.present?
    @commitment = Today::Commitment.progress(user: current_user, journey: @journey)
    @next_action = Strategy::NextAction.for(
      user: current_user,
      session: session,
      journey: @journey
    )
    @open_reveal = open_reveal.to_s.presence
    @planned_battles = current_user.daily_todos.for_day(Date.current).incomplete.ordered.to_a
    @gap_notice = gap_notice
  end

  def render_commitment_gap_stream
    render template: "shared/commitment_gap_refresh", formats: [ :turbo_stream ]
  end
end
