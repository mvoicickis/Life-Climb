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
      created = 0
      ActiveRecord::Base.transaction do
        one_time_goals.find_each do |goal|
          date = goal.scheduled_on.presence || Date.current
          created += 1 if upsert_todo!(goal, date)
        end

        daily_templates.find_each do |goal|
          (@from..@to).each do |date|
            next if goal.scheduled_on.present? && date < goal.scheduled_on

            created += 1 if upsert_todo!(goal, date)
          end
        end
      end
      created
    end

    private

    def one_time_goals
      @user.strategy_goals
        .where(life_area_id: @life_area.id, horizon: "day", repeat: "none")
        .incomplete
        .not_holding
        .ordered
    end

    def daily_templates
      @user.strategy_goals
        .where(life_area_id: @life_area.id, horizon: "day", repeat: "daily")
        .incomplete
        .where("scheduled_on IS NULL OR scheduled_on <= ?", @to)
        .ordered
    end

    # Returns true when a new todo row was created.
    def upsert_todo!(goal, date)
      return false if date.blank?

      todo = DailyTodo.find_or_initialize_by(
        user_id: @user.id,
        strategy_goal_id: goal.id,
        scheduled_on: date
      )
      return false if todo.persisted? && todo.completed?

      todo.assign_attributes(
        title: display_title_for(goal),
        aspect_key: goal.aspect_key,
        position: goal.position,
        tag: "strategy"
      )
      if todo.new_record? && GameRules.daily_open_cap_reached?(@user, date)
        return false
      end
      todo.save!
      todo.previously_new_record?
    end

    def display_title_for(goal)
      Strategy::EnsureFolderQuest.display_title_for(goal)
    end
  end
end
