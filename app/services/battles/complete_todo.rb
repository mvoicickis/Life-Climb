# frozen_string_literal: true

module Battles
  # Completes one DailyTodo the same way Today's checkbox does (AP, juice, day finish).
  class CompleteTodo
    Result = Struct.new(:streak, :personal_best_new, :awarded, keyword_init: true)

    def self.call(todo:, user:, session:, amount: nil, already_logged: false)
      new(todo: todo, user: user, session: session, amount: amount, already_logged: already_logged).call
    end

    def initialize(todo:, user:, session:, amount:, already_logged: false)
      @todo = todo
      @user = user
      @session = session
      @amount = amount
      @already_logged = already_logged
    end

    def call
      raise ArgumentError, "Todo already completed" if @todo.completed?

      day = @todo.strategy_goal
      checklist = day&.practice_tasks&.any?
      # Checklist days log quantity on opted-in objectives only — never again at day finish.
      project = checklist || @already_logged ? nil : day&.quantified_path_project
      if project
        raise ArgumentError, "Amount required" unless valid_amount?(@amount)
      end

      already_paid = WinAlreadyPaid.for_todo?(@todo)
      awarded = already_paid ? 0 : @todo.lp_reward.to_i

      ActiveRecord::Base.transaction do
        if project
          Strategy::Quantity::Log.call(
            project: project,
            amount: @amount,
            user: @user,
            source_day: day,
            daily_todo: @todo
          )
        end
        @todo.update!(completed_at: Time.current)
        finish_linked_strategy_goal!
        unless already_paid
          LifePoints::Award.call(
            user: @user,
            amount: @todo.lp_reward,
            reason: I18n.t("battle.lp_reason", title: @todo.title),
            source: @todo
          )
        end
        Gap::ApplyProgress.call(journey: @user.primary_focused_journey, tier: :todo)
      end

      streak = Climb::Streak.touch!(user: @user)
      pb = Climb::PersonalBest.record!(user: @user, awarded: awarded)
      Today::OvershootBonus.sync!(user: @user)

      Analytics::TrackFirstBattleWon.call(user: @user)

      Result.new(streak: streak, personal_best_new: pb.new_record, awarded: awarded)
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
