# frozen_string_literal: true

module Strategy
  module Quantity
    # Reverse a quantity log tied to a completed battle (undo).
    class Unlog
      def self.call(daily_todo:)
        new(daily_todo: daily_todo).call
      end

      def initialize(daily_todo:)
        @daily_todo = daily_todo
      end

      def call
        return if @daily_todo.blank?

        entry = StrategyQuantityLog.find_by(daily_todo_id: @daily_todo.id)
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
