# frozen_string_literal: true

module GameRules
  MISSION_LP = 50
  JOURNEY_COMPLETE_LP = 250
  BATTLE_TODO_LP = 30
  MAX_DAILY_TODOS = 12
  GAP_DECAY_RATE = 0.008
  DEFAULT_NEW_JOURNEY_GAP = 95.0
  JOURNEY_COMPLETE_GAP_CLAMP = 5.0

  def self.apply_todo_gap!(journey)
    return unless journey

    gap = journey.gap_percent.to_f
    new_gap = (gap * (1.0 - GAP_DECAY_RATE)).clamp(0.0, 100.0).round(2)
    journey.update!(gap_percent: new_gap)
  end
end
