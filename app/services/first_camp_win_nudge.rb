# frozen_string_literal: true

# Clears the post-save first-camp win prompt when the pinned battle is won (any surface).
module FirstCampWinNudge
  class << self
    def clear_after_battle_win!(user:, battle:)
      return if user.blank? || battle.blank?

      journey = battle.life_journey || user.primary_focused_journey
      return if journey.blank?
      return unless journey.first_camp_win_nudge_pending?

      pinned_id = journey.first_camp_pinned_camp_id
      return if pinned_id.blank?

      parent = battle.parent
      return unless parent&.project? && parent.id == pinned_id

      journey.clear_first_camp_win_nudge!
    end
  end
end
