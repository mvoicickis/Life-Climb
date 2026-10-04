# frozen_string_literal: true

module Goals
  # Resolves the player's current active journey and its root StrategyGoal.
  class Current
    Result = Struct.new(:journey, :goal, keyword_init: true)

    class << self
      def call(user:)
        cache = request_cache
        cache[user.id] ||= build(user)
      end

      def journey_for(user:)
        call(user: user).journey
      end

      def goal_for(user:, journey: nil, goal_id: nil)
        if goal_id.present?
          explicit = user.strategy_goals.for_kind("goal").roots.find_by(id: goal_id)
          return explicit if explicit
        end

        journey ||= journey_for(user: user)
        return nil if journey.blank?

        resolve_goal(user: user, journey: journey)
      end

      def clear_cache!(user: nil)
        cache = request_cache
        if user
          cache.delete(user.id)
        else
          cache.clear
        end
      end

      def excluded_journey_ids_for(user:)
        user.life_journeys.where(status: %w[completed archived]).pluck(:id)
      end

      private

      def request_cache
        ::Current.goals_current_by_user_id ||= {}
      end

      def build(user)
        journey = resolve_journey(user)
        goal = journey ? resolve_goal(user: user, journey: journey) : nil
        Result.new(journey: journey, goal: goal)
      end

      def resolve_journey(user)
        user.life_journeys.active.primary_focus.first ||
          user.life_journeys.active.order(:id).first
      end

      def resolve_goal(user:, journey:)
        scoped = user.strategy_goals
          .for_kind("goal")
          .roots
          .where(life_journey_id: journey.id)
          .ordered
          .first
        return scoped if scoped

        user.strategy_goals
          .for_area(journey.life_area_id)
          .for_kind("goal")
          .roots
          .where(life_journey_id: nil)
          .ordered
          .first
      end
    end
  end
end
