# frozen_string_literal: true

require "set"

module Progress
  # Aggregates Progress page analytics for a selected time window.
  class Dashboard
    Period = Struct.new(:key, :label_key, :days, keyword_init: true)

    PERIODS = [
      Period.new(key: "7d", label_key: "progress.periods.d7", days: 7),
      Period.new(key: "30d", label_key: "progress.periods.d30", days: 30),
      Period.new(key: "90d", label_key: "progress.periods.d90", days: 90),
      Period.new(key: "365d", label_key: "progress.periods.d365", days: 365),
      Period.new(key: "all", label_key: "progress.periods.all", days: nil)
    ].freeze

    ASPECT_COLORS = {
      "self" => "#22C55E",
      "relationships" => "#EF476F",
      "career" => "#388CF6",
      "money" => "#F59E0B",
      "home" => "#F97316",
      "learning" => "#885CF6"
    }.freeze

    ASPECT_ICONS = {
      "self" => "💪",
      "relationships" => "❤️",
      "career" => "💼",
      "money" => "💰",
      "home" => "🏠",
      "learning" => "📚"
    }.freeze

    def self.periods
      PERIODS
    end

    def self.call(user:, period: "7d")
      new(user: user, period: period).call
    end

    def initialize(user:, period: "7d")
      @user = user
      @period = normalize_period(period)
    end

    def call
      {
        period: @period,
        periods: PERIODS,
        total_lp: @user.life_points,
        action_points: @user.action_points,
        strategy_points: @user.strategy_points,
        kpis: kpis,
        growth: growth_series,
        categories: category_distribution,
        heatmap: heatmap_grid,
        mountain_summary: mountain_summary,
        projects: [],
        achievements: achievements,
        insights: insights
      }
    end

    private

    def normalize_period(key)
      PERIODS.find { |p| p.key == key.to_s } || PERIODS.first
    end

    def range
      @range ||= begin
        if @period.days.nil?
          earliest_activity_on..Date.current
        else
          (Date.current - (@period.days - 1))..Date.current
        end
      end
    end

    def previous_range
      days = range.count
      (range.begin - days)..(range.begin - 1)
    end

    def earliest_activity_on
      dates = [
        @user.life_point_ledgers.minimum(:created_at)&.to_date,
        @user.missions.minimum(:completed_at)&.to_date,
        @user.daily_todos.where.not(completed_at: nil).minimum(:completed_at)&.to_date,
        @user.created_at.to_date
      ]
      dates.compact.min || Date.current
    end

    def range_time(r)
      r.begin.beginning_of_day..r.end.end_of_day
    end

    def ledgers_in(r)
      @user.life_point_ledgers.where(created_at: range_time(r))
    end

    def positive_lp_in(r)
      ledgers_in(r).where("amount > 0").sum(:amount)
    end

    def completed_tasks_in(r)
      @user.missions.where(completed_at: range_time(r)).count +
        @user.daily_todos.where(completed_at: range_time(r)).count
    end

    def scheduled_tasks_in(r)
      @user.missions.where(scheduled_on: r).count +
        @user.daily_todos.where(scheduled_on: r).count
    end

    def kpis
      lp_now = positive_lp_in(range)
      lp_prev = positive_lp_in(previous_range)
      tasks_now = completed_tasks_in(range)
      tasks_prev = completed_tasks_in(previous_range)
      rate_now = completion_rate(tasks_now, scheduled_tasks_in(range))
      rate_prev = completion_rate(tasks_prev, scheduled_tasks_in(previous_range))

      [
        {
          key: :life_points,
          icon: "⚡",
          label: I18n.t("progress.kpi.life_points"),
          value: @user.action_points,
          suffix: nil,
          delta: percent_delta(lp_now, lp_prev),
          delta_label: I18n.t("progress.kpi.vs_prior"),
          sparkline: daily_lp_sparkline
        },
        {
          key: :tasks,
          icon: "✅",
          label: I18n.t("progress.kpi.tasks"),
          value: tasks_now,
          suffix: nil,
          delta: percent_delta(tasks_now, tasks_prev),
          delta_label: I18n.t("progress.kpi.vs_prior"),
          sparkline: daily_tasks_sparkline
        },
        {
          key: :rate,
          icon: "🎯",
          label: I18n.t("progress.kpi.rate"),
          value: rate_now,
          suffix: "%",
          delta: (rate_now - rate_prev).round,
          delta_label: I18n.t("progress.kpi.vs_prior_pts"),
          sparkline: daily_rate_sparkline
        }
      ]
    end

    def completion_rate(done, scheduled)
      return 0 if scheduled <= 0

      ((done.to_f / scheduled) * 100).round
    end

    def percent_delta(current, previous)
      return 0 if previous.to_f <= 0 && current.to_f <= 0
      return 100 if previous.to_f <= 0 && current.to_f.positive?

      (((current - previous) / previous.to_f) * 100).round
    end

    def days_in_range
      @days_in_range ||= range.to_a
    end

    def daily_lp_map
      @daily_lp_map ||= begin
        map = Hash.new(0)
        ledgers_in(range).where("amount > 0").find_each do |entry|
          map[entry.created_at.to_date] += entry.amount
        end
        map
      end
    end

    def daily_tasks_map
      @daily_tasks_map ||= begin
        map = Hash.new(0)
        @user.missions.where(completed_at: range_time(range)).find_each do |mission|
          map[mission.completed_at.to_date] += 1
        end
        @user.daily_todos.where(completed_at: range_time(range)).find_each do |todo|
          map[todo.completed_at.to_date] += 1
        end
        map
      end
    end

    def growth_series
      days_in_range.map do |day|
        {
          date: day.iso8601,
          label: day.strftime("%b %-d"),
          short: day.strftime("%-d"),
          lp: daily_lp_map[day]
        }
      end
    end

    def daily_lp_sparkline
      sample_days(growth_series.map { |d| d[:lp] })
    end

    def daily_tasks_sparkline
      sample_days(days_in_range.map { |d| daily_tasks_map[d] })
    end

    def daily_rate_sparkline
      sample_days(
        days_in_range.map do |day|
          done = daily_tasks_map[day]
          scheduled = @user.missions.where(scheduled_on: day).count +
                      @user.daily_todos.where(scheduled_on: day).count
          completion_rate(done, scheduled)
        end
      )
    end

    def sample_days(values)
      return values if values.size <= 14

      step = (values.size / 14.0).ceil
      values.each_slice(step).map { |chunk| (chunk.sum / chunk.size.to_f).round }
    end

    def category_distribution
      totals = Hash.new(0)

      @user.missions.where(completed_at: range_time(range)).includes(life_journey: :life_area).find_each do |mission|
        key = mission.aspect_key.presence || mission.life_journey&.life_area&.key || "self"
        key = "self" unless LifeArea::HOME_ASPECT_KEYS.include?(key)
        totals[key] += mission.lp_reward.to_i
      end

      @user.daily_todos.where(completed_at: range_time(range)).find_each do |todo|
        totals[todo.aspect_key] += todo.lp_reward.to_i
      end

      if totals.values.sum.zero?
        ledger_lp = positive_lp_in(range)
        totals["self"] = ledger_lp if ledger_lp.positive?
      end

      grand = totals.values.sum
      return [] if grand <= 0

      LifeArea::HOME_ASPECT_KEYS.filter_map do |key|
        amount = totals[key].to_i
        next if amount <= 0

        {
          key: key,
          label: I18n.t("life_area_catalog.#{key}.name", default: key.humanize),
          icon: ASPECT_ICONS.fetch(key, "✨"),
          color: ASPECT_COLORS.fetch(key, "#22C55E"),
          amount: amount,
          percent: ((amount.to_f / grand) * 100).round
        }
      end.sort_by { |row| -row[:amount] }
    end

    def heatmap_grid
      weeks = 26
      start = Date.current.beginning_of_week(:monday) - ((weeks - 1) * 7)
      finish = Date.current.end_of_week(:monday)
      cells = (start..finish).map do |day|
        future = day > Date.current
        tasks = future ? 0 : day_task_count(day)
        lp = future ? 0 : day_lp(day)
        {
          date: day.iso8601,
          label: day.strftime("%b %-d, %Y"),
          tasks: tasks,
          lp: lp,
          level: future ? 0 : intensity(tasks, lp),
          future: future
        }
      end

      month_labels = []
      prev_month = nil
      weeks.times do |index|
        week_start = start + (index * 7)
        next if week_start.month == prev_month

        month_labels << {
          index: index,
          label: I18n.l(week_start, format: "%b")
        }
        prev_month = week_start.month
      end

      active_days = cells.count { |cell| !cell[:future] && cell[:level].positive? }

      {
        weeks: weeks,
        start: start.iso8601,
        cells: cells,
        active_days: active_days,
        month_labels: month_labels,
        day_labels: [
          { row: 0, label: I18n.t("date.abbr_day_names")[1] }, # Mon
          { row: 2, label: I18n.t("date.abbr_day_names")[3] }, # Wed
          { row: 4, label: I18n.t("date.abbr_day_names")[5] }  # Fri
        ]
      }
    end

    def day_task_count(day)
      @day_task_counts ||= begin
        map = Hash.new(0)
        @user.missions.where.not(completed_at: nil).find_each { |m| map[m.completed_at.to_date] += 1 }
        @user.daily_todos.where.not(completed_at: nil).find_each { |t| map[t.completed_at.to_date] += 1 }
        map
      end
      @day_task_counts[day]
    end

    def day_lp(day)
      @day_lp_counts ||= begin
        map = Hash.new(0)
        @user.life_point_ledgers.where("amount > 0").find_each { |e| map[e.created_at.to_date] += e.amount }
        map
      end
      @day_lp_counts[day]
    end

    def intensity(tasks, lp)
      score = tasks + (lp / 50.0)
      return 0 if score <= 0
      return 1 if score < 1.5
      return 2 if score < 3
      return 3 if score < 5

      4
    end

    def mountain_summary
      journey = @user.primary_focused_journey
      return empty_mountain_summary(journey) unless journey

      goal = @user.strategy_goals.for_area(journey.life_area_id).for_kind("goal").roots.first
      return empty_mountain_summary(journey) unless goal

      plans = goal.children.select(&:plan?)
      projects = plans.flat_map { |plan| plan.children.select(&:project?) }
      plans_done = plans.count(&:completed?)
      projects_done = projects.count(&:completed?)
      current = plans.find { |plan| Strategy::Progress.percent(plan) < 100 } || plans.first

      {
        present: true,
        journey_id: journey.id,
        goal_title: goal.title,
        mountain_percent: Strategy::Progress.percent(goal),
        plans_done: plans_done,
        plans_total: plans.size,
        projects_done: projects_done,
        projects_total: projects.size,
        current_expedition: current&.title,
        strategy_href: true
      }
    end

    def empty_mountain_summary(journey)
      {
        present: false,
        journey_id: journey&.id,
        goal_title: nil,
        mountain_percent: 0,
        plans_done: 0,
        plans_total: 0,
        projects_done: 0,
        projects_total: 0,
        current_expedition: nil,
        strategy_href: journey.present?
      }
    end

    def projects
      []
    end

    def strategy_mountain_percent
      journey = @user.primary_focused_journey
      return 0 unless journey

      goal = @user.strategy_goals.for_area(journey.life_area_id).for_kind("goal").roots.first
      return 0 unless goal

      Strategy::Progress.percent(goal)
    end

    def achievements
      total = @user.action_points
      battles = @user.missions.where.not(completed_at: nil).count +
                @user.daily_todos.where.not(completed_at: nil).count
      mountain = strategy_mountain_percent

      catalog = [
        { key: "first_battle", icon: "⚔", title: I18n.t("progress.achievements.first_battle"), hint: I18n.t("progress.achievements.first_battle_hint"), unlocked: battles >= 1 },
        { key: "lp_100", icon: "⚡", title: I18n.t("progress.achievements.lp_100"), hint: I18n.t("progress.achievements.lp_100_hint"), unlocked: total >= 100 },
        { key: "closer_25", icon: "⛰", title: I18n.t("progress.achievements.closer_25"), hint: I18n.t("progress.achievements.closer_25_hint"), unlocked: mountain >= 25 },
        { key: "lp_1000", icon: "⚡", title: I18n.t("progress.achievements.lp_1000"), hint: I18n.t("progress.achievements.lp_1000_hint"), unlocked: total >= 1000 },
        { key: "battles_100", icon: "🏆", title: I18n.t("progress.achievements.battles_100"), hint: I18n.t("progress.achievements.battles_100_hint"), unlocked: battles >= 100 },
        { key: "closer_50", icon: "🌄", title: I18n.t("progress.achievements.closer_50"), hint: I18n.t("progress.achievements.closer_50_hint"), unlocked: mountain >= 50 },
        { key: "closer_100", icon: "🏔", title: I18n.t("progress.achievements.closer_100"), hint: I18n.t("progress.achievements.closer_100_hint"), unlocked: mountain >= 100 }
      ]

      unlocked = catalog.select { |a| a[:unlocked] }
      unlocked.presence || catalog.first(2)
    end

    def insights
      items = []
      tasks_now = completed_tasks_in(range)
      tasks_prev = completed_tasks_in(previous_range)
      lp_now = positive_lp_in(range)
      lp_prev = positive_lp_in(previous_range)
      cats = category_distribution
      top = cats.first
      weekday_counts = Hash.new(0)

      @user.missions.where(completed_at: range_time(range)).find_each do |m|
        weekday_counts[m.completed_at.wday] += 1
      end
      @user.daily_todos.where(completed_at: range_time(range)).find_each do |t|
        weekday_counts[t.completed_at.wday] += 1
      end

      task_delta = percent_delta(tasks_now, tasks_prev)
      lp_delta = (lp_now.positive? || lp_prev.positive?) ? percent_delta(lp_now, lp_prev) : 0

      # When trends dip, lead with a concrete next action — win today's battle.
      if tasks_prev.positive? && task_delta.negative?
        items << { icon: "📉", text: I18n.t("progress.insights.consistency_down", percent: task_delta.abs) }
        items << { icon: "⚔", text: I18n.t("progress.insights.battle_turnaround") }
      elsif lp_prev.positive? && lp_delta.negative?
        items << { icon: "🌿", text: I18n.t("progress.insights.lp_down_nudge", percent: lp_delta.abs) }
      end

      if weekday_counts.any?
        best_wday = weekday_counts.max_by { |_, v| v }&.first
        if best_wday
          day_name = I18n.t("date.day_names")[best_wday]
          items << { icon: "📅", text: I18n.t("progress.insights.best_day", day: day_name) }
        end
      end

      if top
        items << { icon: top[:icon], text: I18n.t("progress.insights.top_category", category: top[:label], percent: top[:percent]) }
      end

      if tasks_prev.positive? && task_delta.positive?
        items << { icon: "📈", text: I18n.t("progress.insights.consistency_up", percent: task_delta.abs) }
      end

      if lp_now.positive? && lp_prev.positive? && !lp_delta.negative?
        items << {
          icon: "🌿",
          text: I18n.t("progress.insights.lp_change", percent: lp_delta.abs, direction: lp_delta >= 0 ? "more" : "less")
        }
      end

      items.first(4).presence || [ { icon: "✨", text: I18n.t("progress.insights.empty") } ]
    end
  end
end
