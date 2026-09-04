# frozen_string_literal: true

module Strategy
  # Syncs day-horizon strategy goals into daily_todos for the Today feeder.
  class CascadeToDaily
    def self.call(user:, life_area:, from: Date.current.beginning_of_week, to: Date.current.end_of_week)
      new(user:, life_area:, from:, to:).call
    end

    # Drop one camp battle onto Today — used before Mountain wins when area cascade missed it.
    def self.sync_goal!(user:, goal:)
      return nil if goal.blank? || !goal.day? || goal.holding? || goal.life_area.blank?

      new(user: user, life_area: goal.life_area).sync_goal!(goal)
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
          date = surfacing_date_for(goal)
          prune_stale_one_shot_feed!(goal) if pulled_forward?(goal)
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

    def sync_goal!(goal)
      return nil if goal.blank? || !goal.day? || goal.holding? || goal.life_area.blank?

      date =
        if goal.repeat_daily?
          [ Date.current, goal.scheduled_on || Date.current ].max
        else
          surfacing_date_for(goal)
        end
      prune_stale_one_shot_feed!(goal) if !goal.repeat_daily? && pulled_forward?(goal)
      upsert_todo!(goal, date)
      @user.daily_todos.for_day(date).find_by(strategy_goal_id: goal.id)
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

    # One-shots land on scheduled_on when today or future; overdue battles surface today.
    def surfacing_date_for(goal)
      scheduled = goal.scheduled_on.presence || Date.current
      scheduled < Date.current ? Date.current : scheduled
    end

    def pulled_forward?(goal)
      goal.scheduled_on.present? && goal.scheduled_on < Date.current
    end

    # Avoid two open feed rows for the same battle after overdue pull-forward.
    def prune_stale_one_shot_feed!(goal)
      @user.daily_todos
        .where(strategy_goal_id: goal.id)
        .incomplete
        .where("scheduled_on < ?", Date.current)
        .delete_all
    end
  end
end
