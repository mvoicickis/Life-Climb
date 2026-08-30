# frozen_string_literal: true

module Today
  # End-of-day gate: battles cleared plus optional Basics survival check.
  class EndOfDay
    def self.ready?(health:, habits:, habits_gate_enabled:)
      return false unless health&.all_clear?

      return true unless habits_gate_enabled

      habits.blank? || habits.all?(&:survived_today?)
    end

    def self.open_camps(strategy_goal:)
      return [] if strategy_goal.blank?

      plan = strategy_goal.children.for_kind("plan").not_holding.order(:position, :id).first
      return [] unless plan

      plan.children
        .select { |child| child.project? && !child.holding? && !child.completed? }
        .sort_by { |project| [ project.position.to_i, project.id ] }
    end

    def self.tomorrow_battles(user:, journey:)
      return [] if journey.blank?

      user.strategy_goals
        .for_kind("day")
        .where(life_journey_id: journey.id, scheduled_on: Date.current + 1.day)
        .order(:position, :id)
        .to_a
    end
  end
end
