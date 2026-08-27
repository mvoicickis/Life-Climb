# frozen_string_literal: true

module Strategy
  module Quantity
    # Append an amount to a quantified camp or day battle and refresh mountain %.
    class Log
      def self.call(project:, amount:, user:, source_day: nil, daily_todo: nil, practice_task: nil, logged_on: Date.current)
        new(
          project: project,
          amount: amount,
          user: user,
          source_day: source_day,
          daily_todo: daily_todo,
          practice_task: practice_task,
          logged_on: logged_on
        ).call
      end

      def initialize(project:, amount:, user:, source_day:, daily_todo:, practice_task:, logged_on:)
        @project = project
        @amount = BigDecimal(amount.to_s)
        @user = user
        @source_day = source_day
        @daily_todo = daily_todo
        @practice_task = practice_task
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
            source_day: @source_day || (@project.day? ? @project : nil),
            daily_todo: @daily_todo,
            practice_task: @practice_task,
            amount: @amount,
            unit: @project.unit,
            logged_on: @logged_on
          )

          new_total = @project.current_amount.to_d + @amount
          @project.update!(current_amount: new_total)

          # Daily battles stay open after a log — they come back tomorrow.
          should_complete =
            if @project.day?
              false
            elsif @project.quantity_range?
              max = @project.range_max.to_d
              max.positive? && new_total >= max
            elsif @project.quantity_down?
              # Down camps do not auto-complete on sum — climber decides.
              false
            else
              target = @project.target_amount.to_d
              target.positive? && new_total >= target
            end

          if should_complete
            @project.complete!
            Strategy::SyncCompletion.call(project: @project)
          end
        end
        entry
      end
    end
  end
end
