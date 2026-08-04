# frozen_string_literal: true

module Strategy
  module Quantity
    # Reverse a quantity log (battle via daily_todo, or objective via practice_task).
    class Unlog
      def self.call(daily_todo: nil, practice_task: nil)
        new(daily_todo: daily_todo, practice_task: practice_task).call
      end

      def initialize(daily_todo:, practice_task:)
        @daily_todo = daily_todo
        @practice_task = practice_task
      end

      def call
        entry =
          if @practice_task.present?
            StrategyQuantityLog.find_by(practice_task_id: @practice_task.id)
          elsif @daily_todo.present?
            # Plain day battles only — ignore objective-scoped rows tied to the same todo.
            StrategyQuantityLog.where(daily_todo_id: @daily_todo.id, practice_task_id: nil).first
          end
        return if entry.blank?

        project = entry.strategy_goal
        ActiveRecord::Base.transaction do
          amount = entry.amount.to_d
          entry.destroy!

          new_total = [ project.current_amount.to_d - amount, BigDecimal("0") ].max
          project.update!(current_amount: new_total)

          if project.quantified? && new_total < project.target_amount.to_d
            project.reopen!
            Strategy::SyncCompletion.call(project: project)
          end
        end
        true
      end
    end
  end
end
