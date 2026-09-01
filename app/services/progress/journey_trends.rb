# frozen_string_literal: true

require "set"

module Progress
  # Journey-scoped trend series for the Progress page (battles / quantified / habits).
  class JourneyTrends
    WEEKS = 8

    def self.call(user:, journey:)
      new(user: user, journey: journey).call
    end

    def initialize(user:, journey:)
      @user = user
      @journey = journey
    end

    def call
      {
        battles: battles_series,
        quantified: quantified_series,
        habits: habits_this_week
      }
    end

    private

    def week_starts
      @week_starts ||= begin
        current = Date.current.beginning_of_week(:monday)
        ((WEEKS - 1).downto(0)).map { |offset| current - (offset * 7) }
      end
    end

    def window_range
      @window_range ||= week_starts.first.beginning_of_day..(week_starts.last + 6).end_of_day
    end

    def battles_series
      goal_ids = @user.strategy_goals.where(life_journey_id: @journey.id).select(:id)
      todos = @user.daily_todos
        .where(strategy_goal_id: goal_ids)
        .where(completed_at: window_range)
        .pluck(:completed_at)

      return nil if todos.empty?

      counts = Hash.new(0)
      todos.each do |completed_at|
        week = completed_at.to_date.beginning_of_week(:monday)
        counts[week] += 1
      end

      weeks = build_week_points(counts)
      { weeks: weeks, comparison: comparison_for(weeks) }
    end

    def quantified_series
      projects = @user.strategy_goals
        .where(life_journey_id: @journey.id, horizon: "project")
        .not_holding
        .includes(:parent)
        .select(&:quantified?)
        .sort_by { |p| [ p.position.to_i, p.id ] }

      return [] if projects.empty?

      logs_by_goal = @user.strategy_quantity_logs
        .where(strategy_goal_id: projects.map(&:id))
        .where("logged_on <= ?", week_starts.last + 6)
        .order(:logged_on, :id)
        .group_by(&:strategy_goal_id)

      projects.map do |project|
        logs = logs_by_goal[project.id] || []
        running = 0.to_d
        log_index = 0

        weeks = week_starts.map do |start|
          week_end = start + 6
          while log_index < logs.size && logs[log_index].logged_on <= week_end
            running += logs[log_index].amount.to_d
            log_index += 1
          end

          {
            week_start: start.iso8601,
            label: I18n.l(start, format: "%b %-d"),
            value: running.to_f,
            down: false
          }
        end

        weeks.each_with_index do |point, index|
          next if index.zero?

          point[:down] = point[:value] < weeks[index - 1][:value]
        end

        {
          project_id: project.id,
          title: project.title,
          unit: project.unit.to_s,
          target: project.target_amount.to_f,
          quantity_kind: project.try(:quantity_kind_value) || "up",
          range_min: project.try(:range_min)&.to_f,
          range_max: project.try(:range_max)&.to_f,
          lower_is_better: project.try(:quantity_down?) || false,
          weeks: weeks
        }
      end
    end

    def habits_this_week
      habits = @journey.habits.active.visible_on_dashboard.ordered.to_a
      return [] if habits.empty?

      week_days = (0..6).map { |offset| week_starts.last + offset }
      habit_ids = habits.map(&:id)
      week_span = week_days.first..week_days.last

      completion_dates = Completion
        .where(habit_id: habit_ids, completed_on: week_span)
        .pluck(:habit_id, :completed_on)
        .each_with_object(Hash.new { |h, k| h[k] = Set.new }) do |(habit_id, date), memo|
          memo[habit_id] << date
        end

      log_amounts = DailyLog
        .where(habit_id: habit_ids, logged_on: week_span)
        .pluck(:habit_id, :logged_on, :amount)
        .each_with_object(Hash.new { |h, k| h[k] = {} }) do |(habit_id, date, amount), memo|
          memo[habit_id][date] = amount
        end

      habits.map do |habit|
        if habit.quantity_checkin?
          amounts = log_amounts[habit.id]
          {
            habit_id: habit.id,
            name: habit.name,
            quantity: true,
            unit: habit.unit.to_s,
            days: week_days.map do |date|
              amount = amounts[date]
              {
                date: date.iso8601,
                label: I18n.l(date, format: :chart_day),
                done: amounts.key?(date),
                amount: amount
              }
            end
          }
        else
          done_dates = completion_dates[habit.id]
          {
            habit_id: habit.id,
            name: habit.name,
            quantity: false,
            unit: habit.unit.to_s,
            days: week_days.map do |date|
              {
                date: date.iso8601,
                label: I18n.l(date, format: :chart_day),
                done: done_dates.include?(date)
              }
            end
          }
        end
      end
    end

    def build_week_points(counts)
      previous = nil
      week_starts.map do |start|
        value = counts[start].to_i
        point = {
          week_start: start.iso8601,
          label: I18n.l(start, format: "%b %-d"),
          value: value,
          down: previous ? value < previous : false
        }
        previous = value
        point
      end
    end

    def comparison_for(weeks)
      return :flat if weeks.size < 2

      this_week = weeks[-1][:value]
      last_week = weeks[-2][:value]
      if this_week > last_week
        :up
      elsif this_week < last_week
        :down
      else
        :flat
      end
    end
  end
end
