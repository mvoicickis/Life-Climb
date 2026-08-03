# frozen_string_literal: true

module Battles
  # Completes one DailyTodo the same way Today's checkbox does (AP, juice, day finish).
  class CompleteTodo
    Result = Struct.new(:streak, :personal_best_new, keyword_init: true)

    def self.call(todo:, user:, session:, amount: nil)
      new(todo: todo, user: user, session: session, amount: amount).call
    end

    def initialize(todo:, user:, session:, amount:)
      @todo = todo
      @user = user
      @session = session
      @amount = amount
    end

    def call
      raise ArgumentError, "Todo already completed" if @todo.completed?

      project = @todo.strategy_goal&.quantified_path_project
      if project
        raise ArgumentError, "Amount required" unless valid_amount?(@amount)
      end

      ActiveRecord::Base.transaction do
        if project
          Strategy::Quantity::Log.call(
            project: project,
            amount: @amount,
            user: @user,
            source_day: @todo.strategy_goal,
            daily_todo: @todo
          )
        end
        @todo.update!(completed_at: Time.current)
        finish_linked_strategy_goal!
        LifePoints::Award.call(
          user: @user,
          amount: @todo.lp_reward,
          reason: I18n.t("battle.lp_reason", title: @todo.title),
          source: @todo
        )
        Gap::ApplyProgress.call(journey: @user.primary_focused_journey, tier: :todo)
      end

      streak = Climb::Streak.touch!(user: @user)
      pb = Climb::PersonalBest.record!(user: @user, awarded: @todo.lp_reward.to_i)
      Strategy::ProjectCheckQueue.enqueue(
        session: @session,
        project_ids: Strategy::ProjectCheckQueue.from_battles([ @todo.strategy_goal ].compact)
      )

      Result.new(streak: streak, personal_best_new: pb.new_record)
    end

    private

    def valid_amount?(raw)
      return false if raw.blank?

      BigDecimal(raw.to_s).positive?
    rescue ArgumentError
      false
    end

    def finish_linked_strategy_goal!
      goal = @todo.strategy_goal
      return if goal.blank?

      unless goal.repeat_daily?
        goal.complete!
        return
      end

      next_day = [ Date.current + 1.day, @todo.scheduled_on + 1.day ].max
      goal.update!(scheduled_on: next_day, completed_at: nil)
      Strategy::CascadeToDaily.call(user: @user, life_area: goal.life_area)
    end
  end
end
