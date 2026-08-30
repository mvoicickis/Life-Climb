# frozen_string_literal: true

module GameRules
  MISSION_LP = 50
  ROUTE_MISSION_LP = 25
  JOURNEY_COMPLETE_LP = 250
  BATTLE_TODO_LP = 30
  MAX_DAILY_TODOS = 20
  DEFAULT_NEW_JOURNEY_GAP = 95.0

  # Open (incomplete) todos for a day — cap enforcement uses this, not total rows.
  def self.daily_open_count(user, date)
    user.daily_todos.for_day(date).incomplete.count
  end

  def self.daily_open_slots_remaining(user, date)
    MAX_DAILY_TODOS - daily_open_count(user, date)
  end

  def self.daily_open_cap_reached?(user, date)
    daily_open_count(user, date) >= MAX_DAILY_TODOS
  end
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

  # Habits/Basics on Today and in commitment math. Flip to false to hide habits
  # app-wide while focusing on battles-only (single line).
  def self.habits_enabled?
    true
  end
end
