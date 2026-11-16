# frozen_string_literal: true

module Today
  # DailyTodos shown on photo Today for the primary focused journey.
  # Ad-hoc rows (no strategy_goal) stay visible. Strategy-linked rows must belong
  # to the journey or sit under the focused root goal (legacy nil life_journey_id).
  class FocusedDayTodos
    def self.relation(user:, journey:, goal: nil, on: Date.current)
      new(user:, journey:, goal:, on:).relation
    end

    def initialize(user:, journey:, goal: nil, on: Date.current)
      @user = user
      @journey = journey
      @goal = goal
      @on = on
    end

    def relation
      scope = @user.daily_todos.for_day(@on)
      return scope.none if @journey.blank?

      under_ids = under_focused_goal_ids

      scope.left_outer_joins(:strategy_goal).where(
        <<~SQL.squish,
          daily_todos.strategy_goal_id IS NULL
          OR strategy_goals.life_journey_id = :journey_id
          OR daily_todos.strategy_goal_id IN (:under_ids)
        SQL
        journey_id: @journey.id,
        under_ids: under_ids
      )
    end

    private

    # All strategy_goal ids under the focused root (batched by tree level).
    def under_focused_goal_ids
      return [ 0 ] if @goal.blank?
      return [ 0 ] unless @goal.user_id == @user.id

      ids = [ @goal.id ]
      frontier = [ @goal.id ]
      while frontier.any?
        kids = @user.strategy_goals.where(parent_id: frontier).pluck(:id)
        break if kids.empty?

        ids.concat(kids)
        frontier = kids
      end
      ids
    end
  end
end
