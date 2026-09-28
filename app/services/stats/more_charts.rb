# frozen_string_literal: true

module Stats
  class MoreCharts
    WEEKS = 12
    WEEKLY_CHART_LABEL_INDEXES = [0, 3, 7, 11].freeze
    DAILY_CHART_LABEL_INDEXES = [0, 2, 4, 6].freeze

    def self.call(user:, journey: nil)
      new(user: user, journey: journey).call
    end

    def initialize(user:, journey: nil)
      @user = user
      @journey = journey || user.primary_focused_journey
      @battle_wins = BattleWins.call(user: @user, journey: @journey)
      @time_zone = @battle_wins.time_zone
      @local_today = @battle_wins.local_today
      @week_start_current = @local_today.beginning_of_week(:monday)
      @week_starts = (0...WEEKS).map { |i| @week_start_current - (WEEKS - 1 - i).weeks }
      @days = (0..6).map { |offset| @week_start_current + offset }
      @range_from = @week_starts.first
      @range_to = @local_today
    end

    def call
      battle_counts = @battle_wins.counts_by_date(from: @range_from, to: @range_to)
      camp_completions = load_camp_completions
      habit_rows = load_habit_series

      {
        local_today: @local_today,
        week_starts: @week_starts,
        days: @days,
        weekday_wins: weekday_totals(battle_counts),
        weekly: build_mode_payload(
          mode: :weekly,
          battle_counts: battle_counts,
          camp_completions: camp_completions,
          habit_rows: habit_rows
        ),
        daily: build_mode_payload(
          mode: :daily,
          battle_counts: battle_counts,
          camp_completions: camp_completions,
          habit_rows: habit_rows
        )
      }
    end

    private

    def build_mode_payload(mode:, battle_counts:, camp_completions:, habit_rows:)
      if mode == :weekly
        battle_series = bucket_weekly(battle_counts)
        camp_series = bucket_camps_weekly(camp_completions)
        habits = habit_rows.map { |row| row.merge(points: bucket_habit_weekly(row)) }
        value_battles = battle_series.last.to_i
        label_dates = @week_starts
        label_indexes = WEEKLY_CHART_LABEL_INDEXES
        value_camps = camp_series.last.to_i
      else
        battle_series = @days.map { |day| battle_counts[day].to_i }
        camp_series = bucket_camps_daily(camp_completions)
        habits = habit_rows.map { |row| row.merge(points: bucket_habit_daily(row)) }
        value_battles = battle_counts[@local_today].to_i
        label_dates = @days
        label_indexes = DAILY_CHART_LABEL_INDEXES
        value_camps = camp_series.sum
      end

      {
        battles: series_row(
          key: :battles,
          value: value_battles,
          points: battle_series,
          label_dates: label_dates,
          label_indexes: label_indexes
        ),
        camps: series_row(
          key: :camps,
          value: value_camps,
          points: camp_series,
          label_dates: label_dates,
          label_indexes: label_indexes
        ),
        habits: habits.map do |habit|
          series_row(
            key: :habit,
            habit_id: habit[:habit_id],
            habit_name: habit[:name],
            countable: habit[:countable],
            unit: habit[:unit],
            value: habit[:points].sum,
            points: habit[:points],
            label_dates: label_dates,
            label_indexes: label_indexes
          )
        end
      }
    end

    def series_row(key:, value:, points:, label_dates:, label_indexes:, habit_id: nil, habit_name: nil, countable: nil, unit: nil)
      {
        key: key,
        habit_id: habit_id,
        habit_name: habit_name,
        countable: countable,
        unit: unit,
        value: value,
        points: points,
        x_labels: chart_x_labels(label_dates, label_indexes)
      }
    end

    def chart_x_labels(dates, label_indexes)
      dates.each_with_index.map do |date, index|
        label_indexes.include?(index) ? I18n.l(date, format: :stats_more_axis) : ""
      end
    end

    def weekday_totals(battle_counts)
      totals = Array.new(7, 0)
      battle_counts.each do |date, wins|
        next if wins.to_i <= 0

        totals[(date.cwday - 1) % 7] += wins
      end
      max = totals.max.to_i
      max = 1 if max <= 0
      { counts: totals, max: max }
    end

    def bucket_weekly(counts)
      @week_starts.map do |week_start|
        week_end = week_start + 6
        sum = 0
        (week_start..week_end).each do |date|
          next if date > @range_to

          sum += counts[date].to_i
        end
        sum
      end
    end

    def bucket_camps_weekly(completions)
      @week_starts.map do |week_start|
        week_end = week_start + 6
        completions.count do |completed_on|
          completed_on >= week_start && completed_on <= week_end && completed_on <= @range_to
        end
      end
    end

    def bucket_camps_daily(completions)
      @days.map { |day| completions.count { |completed_on| completed_on == day } }
    end

    def load_camp_completions
      projects = camp_projects
      return [] if projects.empty?

      project_ids = projects.map(&:id)
      @user.strategy_goals
        .where(id: project_ids)
        .where.not(completed_at: nil)
        .pluck(:completed_at)
        .map { |stamp| stamp.in_time_zone(@time_zone).to_date }
    end

    def camp_projects
      return [] unless @journey

      @user.strategy_goals
        .where(life_journey_id: @journey.id, horizon: "project")
        .not_holding
        .includes(:parent, :children)
        .order(:position, :id)
        .select(&:path_level_camp?)
    end

    def load_habit_series
      return [] unless GameRules.habits_enabled?
      return [] unless @journey

      habits = @user.habits.active.ordered.where(
        "life_journey_id = ? OR area_id = ?",
        @journey.id,
        @journey.life_area_id
      ).to_a
      return [] if habits.empty?

      habit_ids = habits.map(&:id)
      completion_rows = Completion.where(user_id: @user.id, habit_id: habit_ids, completed_on: @range_from..@range_to)
        .pluck(:habit_id, :completed_on)
      log_rows = DailyLog.where(user_id: @user.id, habit_id: habit_ids, logged_on: @range_from..@range_to)
        .pluck(:habit_id, :logged_on, :amount)

      habits.map do |habit|
        {
          habit_id: habit.id,
          name: habit.name,
          countable: habit.quantity_checkin?,
          unit: habit.unit,
          completion_rows: completion_rows.select { |hid, _| hid == habit.id },
          log_rows: log_rows.select { |hid, _, _| hid == habit.id }
        }
      end
    end

    def bucket_habit_weekly(row)
      @week_starts.map do |week_start|
        week_end = week_start + 6
        if row[:countable]
          row[:log_rows].sum do |_, logged_on, amount|
            logged_on >= week_start && logged_on <= week_end && logged_on <= @range_to ? amount.to_f : 0
          end
        else
          row[:completion_rows].count do |_, completed_on|
            completed_on >= week_start && completed_on <= week_end && completed_on <= @range_to
          end
        end
      end
    end

    def bucket_habit_daily(row)
      @days.map do |day|
        if row[:countable]
          row[:log_rows].sum do |_, logged_on, amount|
            logged_on == day ? amount.to_f : 0
          end
        else
          row[:completion_rows].count { |_, completed_on| completed_on == day }
        end
      end
    end
  end
end
