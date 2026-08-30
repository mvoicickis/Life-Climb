# frozen_string_literal: true

module Admin
  # Aggregates SaaS-style visibility metrics for the admin dashboard.
  class Metrics
    LOOKBACK_DAYS = 30

    def self.call(lookback_days: LOOKBACK_DAYS)
      new(lookback_days:).call
    end

    def self.export_csv(cards)
      require "csv"
      CSV.generate(headers: true) do |csv|
        csv << %w[metric value]
        cards.each { |key, value| csv << [ key, value ] }
      end
    end

    def initialize(lookback_days:)
      @lookback_days = lookback_days
      @today = Date.current
      @range_start = @today - (lookback_days - 1)
    end

    def call
      {
        cards: cards,
        charts: charts,
        recent_users: User.order(created_at: :desc).limit(12),
        recent_feedbacks: Feedback.includes(:user).newest_first.limit(8),
        recent_ledgers: LifePointLedger.includes(:user).order(created_at: :desc).limit(12)
      }
    end

    private

    def cards
      {
        users_total: User.count,
        users_week: User.where(created_at: 7.days.ago.beginning_of_day..).count,
        users_month: User.where(created_at: @today.beginning_of_month.beginning_of_day..).count,
        battles_completed: completed_battles_count,
        projects_completed: StrategyGoal.for_kind("project").where.not(completed_at: nil).count,
        onboarding_done: User.where.not(onboarding_completed_at: nil).count,
        onboarding_pending: User.where(onboarding_completed_at: nil).count
      }
    end

    def charts
      {
        users_per_day: series_for(User, :created_at),
        life_points_per_day: ledger_series,
        battles_per_day: battle_series
      }
    end

    def completed_battles_count
      Mission.where.not(completed_at: nil).count +
        DailyTodo.where.not(completed_at: nil).count +
        StrategyGoal.battles.where.not(completed_at: nil).count
    end

    def series_for(scope, column)
      rows = scope.where(column => @range_start.beginning_of_day..).group(Arel.sql("date(#{column})")).count
      fill_days(rows)
    end

    def ledger_series
      rows = LifePointLedger.where(created_at: @range_start.beginning_of_day..)
                            .where("amount > 0")
                            .group(Arel.sql("date(created_at)"))
                            .sum(:amount)
      fill_days(rows)
    end

    def battle_series
      mission_rows = Mission.where.not(completed_at: nil)
                            .where(completed_at: @range_start.beginning_of_day..)
                            .group(Arel.sql("date(completed_at)")).count
      todo_rows = DailyTodo.where.not(completed_at: nil)
                           .where(completed_at: @range_start.beginning_of_day..)
                           .group(Arel.sql("date(completed_at)")).count
      day_rows = StrategyGoal.battles.where.not(completed_at: nil)
                             .where(completed_at: @range_start.beginning_of_day..)
                             .group(Arel.sql("date(completed_at)")).count

      merged = Hash.new(0)
      [ mission_rows, todo_rows, day_rows ].each do |rows|
        rows.each { |day, count| merged[normalize_day(day)] += count.to_i }
      end
      fill_days(merged)
    end

    def fill_days(rows)
      normalized = rows.transform_keys { |k| normalize_day(k) }
      (@range_start..@today).map do |day|
        { date: day.iso8601, label: day.strftime("%b %-d"), value: normalized[day].to_i }
      end
    end

    def normalize_day(value)
      case value
      when Date then value
      when Time, ActiveSupport::TimeWithZone then value.to_date
      else Date.parse(value.to_s)
      end
    rescue ArgumentError, TypeError
      @today
    end
  end
end
