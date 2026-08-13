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
        day = @todo.strategy_goal
        if day&.practice_tasks&.any?
          # Shell undo resets everything. Objective undo already reversed its own log.
          if @reset_objectives
            day.practice_tasks.find_each do |task|
              Strategy::Quantity::Unlog.call(practice_task: task)
            end
          end
        else
          Strategy::Quantity::Unlog.call(daily_todo: @todo)
        end

        @todo.update!(completed_at: nil)
        day&.reopen! unless day&.repeat_daily?
        if @reset_objectives && day&.practice_tasks&.any?
          day.practice_tasks.find_each(&:reopen!)
        end
      end
      Today::OvershootBonus.sync!(user: @user)
      true
    end
  end
end
