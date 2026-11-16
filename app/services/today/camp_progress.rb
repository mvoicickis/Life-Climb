# frozen_string_literal: true

module Today
  # Focused goal's current camp — won/total for the Today goal card (data only).
  # Current camp = Strategy::PathProject.resolve. Wins match Stats::BattleWins#by_camp.
  class CampProgress
    def self.call(user:, journey:, goal:)
      new(user:, journey:, goal:).call
    end

    def initialize(user:, journey:, goal:)
      @user = user
      @journey = journey
      @goal = goal
    end

    def call
      return nil if @user.blank? || @journey.blank? || @goal.blank?
      return nil unless @goal.user_id == @user.id
      return nil unless @goal.life_journey_id == @journey.id

      camp = Strategy::PathProject.resolve(user: @user, journey: @journey)
      return nil if camp.blank?
      return nil unless camp.user_id == @user.id
      return nil unless camp.life_journey_id == @journey.id
      return nil unless camp.root_goal&.id == @goal.id

      battle_ids = Strategy::BattleIdsByProject.call(
        user: @user,
        journey: @journey,
        projects: [ camp ]
      )[camp.id] || []

      total = battle_ids.size
      won = wins_for(battle_ids)
      percent =
        if camp.completed_at.present?
          100
        elsif total.zero?
          0
        else
          ((won.to_f / total) * 100).round
        end

      {
        camp_id: camp.id,
        camp_title: camp.title,
        won: won,
        total: total,
        percent: percent
      }
    end

    private

    # Same win sources as Stats::BattleWins#by_camp — batched, no per-battle queries.
    def wins_for(battle_ids)
      return 0 if battle_ids.empty?

      won = 0
      Battles::WinsOnLocalDate.one_shot_battles_won(user: @user)
        .where(id: battle_ids)
        .pluck(:id)
        .each { won += 1 }

      Battles::WinsOnLocalDate.recurring_strategy_todos_won(user: @user)
        .where(strategy_goal_id: battle_ids)
        .pluck(:strategy_goal_id)
        .each { won += 1 }

      won
    end
  end
end
