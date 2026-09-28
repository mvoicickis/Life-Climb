# frozen_string_literal: true

module Battles
  # Mountain camp "won" read model for a calendar day — mirrors mountain_trail_done_today?.
  class DoneOnDate
    def self.for(user:, goal:, on:)
      new(user: user, goal: goal, on: on).call
    end

    def initialize(user:, goal:, on:)
      @user = user
      @goal = goal
      @on = on
    end

    def call
      return false if @goal.blank? || @user.blank?

      unless @goal.try(:repeat_recurring?)
        return @goal.completed_at.present? if @goal.respond_to?(:completed_at)
        return @goal.completed? if @goal.respond_to?(:completed?)

        return false
      end

      todo = @user.daily_todos.for_day(@on).find_by(strategy_goal_id: @goal.id)
      todo&.completed_at.present?
    end
  end
end
