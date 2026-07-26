# frozen_string_literal: true

module Strategy
  # Syncs day-horizon strategy goals into daily_todos for the Today feeder.
  class CascadeToDaily
    def self.call(user:, life_area:, from: Date.current.beginning_of_week, to: Date.current.end_of_week)
      new(user:, life_area:, from:, to:).call
    end

    def initialize(user:, life_area:, from:, to:)
      @user = user
      @life_area = life_area
      @from = from
      @to = to
    end

    def call
      day_goals = @user.strategy_goals
        .where(life_area_id: @life_area.id, horizon: "day")
        .where(scheduled_on: @from..@to)
        .ordered

      created = 0
      ActiveRecord::Base.transaction do
        day_goals.each do |goal|
          todo = @user.daily_todos.find_or_initialize_by(strategy_goal_id: goal.id)
          next if todo.persisted? && todo.completed?

          todo.assign_attributes(
            title: goal.title,
            scheduled_on: goal.scheduled_on,
            aspect_key: goal.aspect_key,
            position: goal.position,
            lp_reward: GameRules::BATTLE_TODO_LP,
            tag: "strategy"
          )
          if todo.new_record?
            # Cap: skip if day is full and we're creating fresh.
            day_count = @user.daily_todos.for_day(goal.scheduled_on).count
            next if day_count >= GameRules::MAX_DAILY_TODOS
          end
          todo.save!
          created += 1 if todo.previously_new_record?
        end
      end
      created
    end
  end
end
