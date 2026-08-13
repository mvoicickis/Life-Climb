# frozen_string_literal: true

module Battles
  # Option B: keep AP on undo, never pay twice for the same battle.
  # Wins may be ledgered on the DailyTodo (Today / CompleteDay) or the
  # StrategyGoal day (BattleWins). Either source blocks the other path.
  # MissSettlement rows use the same DailyTodo source with amount <= 0 — those
  # must NOT count as a paid win.
  class WinAlreadyPaid
    def self.for_todo?(todo)
      return false if todo.blank?
      return true if positive_ledger?(todo)

      goal = todo.strategy_goal
      goal.present? && positive_ledger?(goal)
    end

    def self.for_battle?(battle, todo: nil)
      return false if battle.blank?
      return true if positive_ledger?(battle)

      linked = todo || battle.user.daily_todos.for_day.find_by(strategy_goal_id: battle.id)
      linked.present? && positive_ledger?(linked)
    end

    def self.positive_ledger?(source)
      return false if source.blank?

      LifePointLedger.where(source: source).where("amount > 0").exists?
    end
  end
end
