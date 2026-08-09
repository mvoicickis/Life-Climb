# frozen_string_literal: true

module Today
  # Soft AP loss when a timed DailyTodo window ends without a win.
  class MissSettlement
    def self.apply!(user:, date: Date.current, now: Time.current)
      new(user:, date:, now:).apply!
    end

    def initialize(user:, date: Date.current, now: Time.current)
      @user = user
      @date = date
      @now = now
    end

    def apply!
      return unless @user.planning_v2?

      todos = @user.daily_todos.for_day(@date).incomplete
        .where.not(start_time: nil).where.not(end_time: nil)
        .where(miss_settled_at: nil)

      todos.find_each do |todo|
        settle!(todo) if past_window?(todo)
      end
    end

    private

    def past_window?(todo)
      @now >= todo.window_end_at
    end

    def settle!(todo)
      penalty = (todo.lp_reward.to_i / 2.0).floor
      ActiveRecord::Base.transaction do
        if Today::DayShield.available?(user: @user, date: @date) && Today::DayShield.consume!(user: @user, date: @date)
          @user.life_point_ledgers.create!(
            amount: 0,
            reason: I18n.t("dash.timeline.ledger_shielded", title: todo.title),
            source: todo
          )
        elsif penalty.positive?
          LifePoints::Award.call(
            user: @user,
            amount: -penalty,
            reason: I18n.t("dash.timeline.ledger_miss", title: todo.title, amount: penalty),
            source: todo
          )
        end
        todo.update!(miss_settled_at: @now)
      end
    end
  end
end
