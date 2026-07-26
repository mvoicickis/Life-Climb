# frozen_string_literal: true

module Strategy
  # Next incomplete Strategy battle after today — keeps the climb never empty.
  class UpcomingBattle
    def self.for(user:, journey:, after: Date.current)
      new(user:, journey:, after:).call
    end

    def initialize(user:, journey:, after:)
      @user = user
      @journey = journey
      @after = after
    end

    def call
      return nil if @journey.blank?

      area_id = @journey.life_area_id
      goal = @user.strategy_goals.for_area(area_id).for_kind("goal").roots.first
      return nil if goal.blank?

      battles = Progress.battles_under(goal)
        .select { |b| b.completed_at.blank? && b.scheduled_on.present? && b.scheduled_on > @after }
        .sort_by { |b| [ b.scheduled_on, b.position, b.id ] }

      battle = battles.first
      return nil if battle.blank?

      {
        title: battle.title,
        scheduled_on: battle.scheduled_on,
        strategy_goal: battle,
        tomorrow: battle.scheduled_on == @after + 1.day
      }
    end
  end
end
