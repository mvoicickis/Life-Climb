# frozen_string_literal: true

module GameRules
  MISSION_LP = 50
  JOURNEY_COMPLETE_LP = 250
  BATTLE_TODO_LP = 30
  MAX_DAILY_TODOS = 12
  DEFAULT_NEW_JOURNEY_GAP = 95.0
  JOURNEY_COMPLETE_GAP_CLAMP = 5.0

  # Alignment-stack progress weights (basis points = percent * 100 of remaining gap).
  # todo << mission — small daily actions must not chew the mountain.
  TODO_GAP_BP = 15
  MISSION_DEFAULT_GAP_BP = 80
  TODO_ABS_CAP = 0.25
  MISSION_ABS_CAP = 1.5
  TARGET_GAP_BP = 20
  TARGET_ABS_CAP = 0.4
end
