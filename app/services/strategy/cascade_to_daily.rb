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

      today = Date.current
      new(user: user, life_area: goal.life_area, from: today, to: today).sync_goal!(goal)
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
        DueDayBattles.entries(user: @user, life_area: @life_area, from: @from, to: @to).each do |entry|
          goal = entry.goal
          date = entry.on
          if !goal.repeat_recurring? && DueDayBattles.pulled_forward?(goal)
            prune_stale_one_shot_feed!(goal)
          end
          created += 1 if upsert_todo!(goal, date)
        end
      end
      created
    end

    def sync_goal!(goal)
      return nil if goal.blank? || !goal.day? || goal.holding? || goal.life_area.blank?

      date =
        if goal.repeat_daily?
          [ Date.current, goal.scheduled_on || Date.current ].max
        elsif goal.repeat_weekly?
          candidate = [ Date.current, goal.scheduled_on || Date.current ].max
          goal.repeats_on?(candidate) ? candidate : nil
        else
          DueDayBattles.surfacing_date_for(goal)
        end
      return nil if date.blank?

      prune_stale_one_shot_feed!(goal) if !goal.repeat_recurring? && DueDayBattles.pulled_forward?(goal)
      upsert_todo!(goal, date)
      @user.daily_todos.for_day(date).find_by(strategy_goal_id: goal.id)
    end

    private

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
