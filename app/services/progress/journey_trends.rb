# frozen_string_literal: true

require "set"

module Progress
  # Journey-scoped trend series for the Progress page (camps / battles / habits).
  class JourneyTrends
    WEEKS = 8
    MONTHS = 6

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
        camps: camps_series,
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

    def daily_dates
      @daily_dates ||= begin
        start = Date.current.beginning_of_week(:monday)
        (0..6).map { |offset| start + offset }
      end
    end

    def month_starts
      @month_starts ||= begin
        current = Date.current.beginning_of_month
        ((MONTHS - 1).downto(0)).map { |offset| current.prev_month(offset) }
      end
    end

    def window_range
      @window_range ||= week_starts.first.beginning_of_day..(week_starts.last + 6).end_of_day
    end

    def camp_projects
      @camp_projects ||= @user.strategy_goals
        .where(life_journey_id: @journey.id, horizon: "project")
        .not_holding
        .includes(:parent, :children)
        .order(:position, :id)
        .select(&:path_level_camp?)
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

      weeks = build_incremental_points(week_starts, ->(start) { I18n.l(start, format: "%b %-d") }) { |start| counts[start].to_i }
      { weeks: weeks, comparison: comparison_for(weeks) }
    end

    def camps_series
      projects = camp_projects
      return [] if projects.empty?

      quantified_ids = projects.select(&:quantified?).map(&:id)
      logs_by_goal = load_quantity_logs(quantified_ids)
      battle_map = battle_ids_by_project(projects)
      completions_by_project = load_completions_by_project(battle_map)

      projects.map do |project|
        kind = project.quantified? ? "quantified" : "battles"
        target = project.target_amount.to_f if project.quantified?
        wins = completions_by_project[project.id] || []

        series =
          if project.quantified?
            logs = logs_by_goal[project.id] || []
            {
              daily: cumulative_quantity_buckets(
                logs, daily_dates, ->(date) { I18n.l(date, format: :chart_day) }
              ) { |date| date },
              weekly: cumulative_quantity_buckets(
                logs, week_starts, ->(start) { I18n.l(start, format: "%b %-d") }
              ) { |start| start + 6 },
              monthly: cumulative_quantity_buckets(
                logs, month_starts, ->(start) { I18n.l(start, format: "%b %Y") }
              ) { |start| start.end_of_month }
            }
          else
            {
              daily: cumulative_win_buckets(
                wins, daily_dates, ->(date) { I18n.l(date, format: :chart_day) }
              ) { |date| date.end_of_day },
              weekly: cumulative_win_buckets(
                wins, week_starts, ->(start) { I18n.l(start, format: "%b %-d") }
              ) { |start| (start + 6).end_of_day },
              monthly: cumulative_win_buckets(
                wins, month_starts, ->(start) { I18n.l(start, format: "%b %Y") }
              ) { |start| start.end_of_month.end_of_day }
            }
          end

        {
          project_id: project.id,
          title: project.title,
          kind: kind,
          accent_hex: project.trail_accent_hex,
          unit: project.unit.to_s,
          target: target,
          stat_label: camp_stat_label(project, win_count: wins.size),
          target_line: quantified_target_line(project),
          series: series
        }
      end
    end

    def load_quantity_logs(project_ids)
      return {} if project_ids.empty?

      @user.strategy_quantity_logs
        .where(strategy_goal_id: project_ids)
        .where("logged_on <= ?", data_range_end)
        .order(:logged_on, :id)
        .group_by(&:strategy_goal_id)
    end

    def battle_ids_by_project(projects)
      goals = @user.strategy_goals
        .where(life_journey_id: @journey.id)
        .select(:id, :parent_id, :horizon, :title)
        .to_a
      by_parent = goals.group_by(&:parent_id)

      projects.each_with_object({}) do |project, memo|
        memo[project.id] = collect_battle_ids(project.id, by_parent)
      end
    end

    def collect_battle_ids(node_id, by_parent)
      (by_parent[node_id] || []).flat_map do |child|
        if child.horizon == "day"
          Strategy::EnsureFolderQuest.checklist_host?(child) ? [] : [ child.id ]
        else
          collect_battle_ids(child.id, by_parent)
        end
      end
    end

    def load_completions_by_project(battle_map)
      battle_to_project = {}
      battle_map.each do |project_id, battle_ids|
        battle_ids.each { |battle_id| battle_to_project[battle_id] = project_id }
      end

      return {} if battle_to_project.empty?

      range = data_range_start.beginning_of_day..data_range_end.end_of_day
      grouped = Hash.new { |hash, key| hash[key] = [] }

      @user.daily_todos
        .where(strategy_goal_id: battle_to_project.keys)
        .where.not(completed_at: nil)
        .where(completed_at: range)
        .pluck(:strategy_goal_id, :completed_at)
        .each do |battle_id, completed_at|
          project_id = battle_to_project[battle_id]
          grouped[project_id] << completed_at
        end

      grouped
    end

    def data_range_start
      [ daily_dates.first, week_starts.first, month_starts.first ].min
    end

    def data_range_end
      [ daily_dates.last, week_starts.last + 6, month_starts.last.end_of_month ].max
    end

    def cumulative_quantity_buckets(logs, buckets, label_for, &bucket_end_for)
      running = 0.to_d
      log_index = 0

      buckets.map do |bucket|
        bucket_end = bucket_end_for.call(bucket)
        while log_index < logs.size && logs[log_index].logged_on <= bucket_end
          running += logs[log_index].amount.to_d
          log_index += 1
        end

        { label: label_for.call(bucket), value: running.to_f, down: false }
      end.then { |points| mark_down(points) }
    end

    def cumulative_win_buckets(completions, buckets, label_for, &bucket_end_for)
      sorted = completions.sort
      index = 0
      running = 0

      buckets.map do |bucket|
        bucket_end = bucket_end_for.call(bucket)
        while index < sorted.size && sorted[index] <= bucket_end
          running += 1
          index += 1
        end

        { label: label_for.call(bucket), value: running.to_f, down: false }
      end.then { |points| mark_down(points) }
    end

    def mark_down(points)
      points.each_with_index do |point, index|
        next if index.zero?

        point[:down] = point[:value] < points[index - 1][:value]
      end
      points
    end

    def camp_stat_label(project, win_count: nil)
      if project.quantified?
        current = format_quantity(project.current_amount)
        unit = project.unit.to_s.strip
        if project.target_amount.present? && project.target_amount.to_d.positive?
          "#{current} / #{format_quantity(project.target_amount)} #{unit}".strip
        else
          [ current, unit.presence ].compact.join(" ")
        end
      else
        wins = win_count.to_i
        if wins.positive?
          I18n.t("strategy.rpg.project_battles_won", count: wins)
        else
          days = project_battle_days(project)
          if days.any?
            I18n.t("strategy.rpg.project_battles_planned", count: days.size)
          else
            I18n.t("strategy.rpg.project_battles_won", count: 0)
          end
        end
      end
    end

    def quantified_target_line(project)
      return unless project.quantified?

      I18n.t(
        "progress.trends.target_line",
        target: format_quantity(project.target_amount),
        unit: project.unit.to_s
      )
    end

    def project_battle_days(project)
      days =
        if project.association(:children).loaded?
          project.children.select(&:day?)
        else
          project.children.where(horizon: "day").to_a
        end
      days.reject { |day| Strategy::EnsureFolderQuest.checklist_host?(day) }
    end

    def format_quantity(value)
      n = value.to_d
      return n.to_i.to_s if n == n.to_i

      format("%.1f", n)
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

    def build_incremental_points(buckets, label_for)
      previous = nil
      buckets.map do |bucket|
        value = yield(bucket)
        point = { label: label_for.call(bucket), value: value, down: false }
        point[:down] = previous ? value < previous : false
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
