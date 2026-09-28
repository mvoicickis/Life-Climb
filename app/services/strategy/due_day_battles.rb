# frozen_string_literal: true

module Strategy
  # Read-only: strategy day battles that CascadeToDaily would sync, in the same order.
  class DueDayBattles
    Entry = Struct.new(:goal, :on, keyword_init: true)

    def self.entries(user:, life_area:, from:, to:)
      new(user: user, life_area: life_area, from: from, to: to).entries
    end

    def self.on(user:, life_area:, on:)
      entries(user: user, life_area: life_area, from: on, to: on)
        .select { |entry| entry.on == on }
        .map(&:goal)
    end

    def self.surfacing_date_for(goal, reference: Date.current)
      scheduled = goal.scheduled_on.presence || reference
      scheduled < reference ? reference : scheduled
    end

    def self.pulled_forward?(goal, reference: Date.current)
      goal.scheduled_on.present? && goal.scheduled_on < reference
    end

    def initialize(user:, life_area:, from:, to:)
      @user = user
      @life_area = life_area
      @from = from
      @to = to
    end

    def entries
      list = []
      reference = Date.current

      one_time_goals.find_each do |goal|
        date = self.class.surfacing_date_for(goal, reference: reference)
        list << Entry.new(goal: goal, on: date)
      end

      daily_templates.find_each do |goal|
        (@from..@to).each do |date|
          next if goal.scheduled_on.present? && date < goal.scheduled_on

          list << Entry.new(goal: goal, on: date)
        end
      end

      weekly_templates.find_each do |goal|
        (@from..@to).each do |date|
          next if goal.scheduled_on.present? && date < goal.scheduled_on
          next unless goal.repeats_on?(date)

          list << Entry.new(goal: goal, on: date)
        end
      end

      list
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

    def weekly_templates
      @user.strategy_goals
        .where(life_area_id: @life_area.id, horizon: "day", repeat: "weekly")
        .incomplete
        .where("scheduled_on IS NULL OR scheduled_on <= ?", @to)
        .ordered
    end
  end
end
