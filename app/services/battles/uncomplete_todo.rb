# frozen_string_literal: true

module Battles
  # Reopens a completed DailyTodo (quantity unlog + day reopen). Used by Today undo.
  class UncompleteTodo
    def self.call(todo:, user:, reset_objectives: true)
      new(todo: todo, user: user, reset_objectives: reset_objectives).call
    end

    def initialize(todo:, user:, reset_objectives:)
      @todo = todo
      @user = user
      @reset_objectives = reset_objectives
    end

    def call
      return false unless @todo.completed?

      ActiveRecord::Base.transaction do
        Strategy::Quantity::Unlog.call(daily_todo: @todo)
        @todo.update!(completed_at: nil)
        day = @todo.strategy_goal
        day&.reopen! unless day&.repeat_daily?
        if @reset_objectives && day&.practice_tasks&.any?
          day.practice_tasks.find_each(&:reopen!)
        end
      end
      true
    end
  end
end
