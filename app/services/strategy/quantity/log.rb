# frozen_string_literal: true

module Strategy
  module Quantity
    # Append an amount to a quantified path-level project and refresh mountain %.
    class Log
      def self.call(project:, amount:, user:, source_day: nil, daily_todo: nil, logged_on: Date.current)
        new(
          project: project,
          amount: amount,
          user: user,
          source_day: source_day,
          daily_todo: daily_todo,
          logged_on: logged_on
        ).call
      end

      def initialize(project:, amount:, user:, source_day:, daily_todo:, logged_on:)
        @project = project
        @amount = BigDecimal(amount.to_s)
        @user = user
        @source_day = source_day
        @daily_todo = daily_todo
        @logged_on = logged_on
      end

      def call
        raise ArgumentError, "Project must be quantified" unless @project&.quantified?
        raise ArgumentError, "Amount must be positive" if @amount <= 0

        entry = nil
        ActiveRecord::Base.transaction do
          entry = StrategyQuantityLog.create!(
            user: @user,
            strategy_goal: @project,
            source_day: @source_day,
            daily_todo: @daily_todo,
            amount: @amount,
            unit: @project.unit,
            logged_on: @logged_on
          )

          new_total = @project.current_amount.to_d + @amount
          attrs = { current_amount: new_total }
          @project.update!(attrs)

          if new_total >= @project.target_amount.to_d
            @project.complete!
            Strategy::SyncCompletion.call(project: @project)
          end
        end
        entry
      end
    end
  end
end
