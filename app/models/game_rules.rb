# frozen_string_literal: true

module GameRules
  MISSION_LP = 50
  ROUTE_MISSION_LP = 25
  JOURNEY_COMPLETE_LP = 250
  BATTLE_TODO_LP = 30
  MAX_DAILY_TODOS = 20
  DEFAULT_NEW_JOURNEY_GAP = 95.0
  JOURNEY_COMPLETE_GAP_CLAMP = 5.0

  # Strategy Points — earned for planning / breaking goals down.
  STRATEGY_GOAL_SP = 100
  STRATEGY_FIRST_PLAN_SP = 50
  STRATEGY_FIRST_PROJECT_SP = 75
  STRATEGY_COMPLETE_SP = 500
  STRATEGY_CHILD_SP = 5
  # Legacy aliases
  STRATEGY_LOCK_SP = STRATEGY_GOAL_SP
  STRATEGY_WEEK_BREAKDOWN_SP = 25

  # Alignment-stack progress weights (basis points = percent * 100 of remaining gap).
  # todo << mission — small daily actions must not chew the mountain.
  TODO_GAP_BP = 15
  MISSION_DEFAULT_GAP_BP = 80
  TODO_ABS_CAP = 0.25
  MISSION_ABS_CAP = 1.5
  TARGET_GAP_BP = 20
  TARGET_ABS_CAP = 0.4

  # Habits are hidden from the UI while we get the goal -> projects -> battles
  # loop right. Flip to true to bring Habits back (single line). While false,
  # Today shows battles only, and the day percent / commitment are battles-only.
  def self.habits_enabled?
    false
  end
end
