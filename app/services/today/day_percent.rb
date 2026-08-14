# frozen_string_literal: true

module Today
  # Display / award input only — not survival. Averages today's habit and battle
  # item percentages. Standard/healthy-range habits are excluded (no invented %).
  class DayPercent
    Result = Struct.new(:percent, :parts_count, keyword_init: true)

    def self.call(user:, date: Date.current, habits: nil, todos: nil)
      new(user: user, date: date, habits: habits, todos: todos).call
    end

    def initialize(user:, date:, habits:, todos:)
      @user = user
      @date = date
      @habits = habits
      @todos = todos
    end

    def call
      parts = battle_parts
      parts += habit_parts if GameRules.habits_enabled?
      return Result.new(percent: nil, parts_count: 0) if parts.empty?

      Result.new(
        percent: (parts.sum.to_f / parts.size).round,
        parts_count: parts.size
      )
    end

    private

    def habit_parts
      habits.map do |habit|
        next if habit.standard?

        if habit.binary_checkin?
          habit.completed_today? ? 100 : 0
        else
          # Growth quantity — uncapped; nil would only appear for standard (skipped).
          habit.goal_progress_percent.to_i
        end
      end.compact
    end

    def battle_parts
      todos.map { |todo| todo.completed? ? 100 : 0 }
    end

    def habits
      @habits || @user.habits.active.on_home.to_a
    end

    def todos
      @todos || @user.daily_todos.for_day(@date).to_a
    end
  end
end
