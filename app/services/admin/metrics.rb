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
        excluded_users: User.privileged.count,
        recent_users: metrics_users.order(created_at: :desc).limit(12),
        recent_feedbacks: Feedback.includes(:user).newest_first.limit(8),
        recent_ledgers: LifePointLedger.includes(:user)
                                       .where(user_id: metrics_user_ids)
                                       .order(created_at: :desc)
                                       .limit(12)
      }
    end

    private

    def metrics_users
      User.excluding_privileged
    end

    def metrics_user_ids
      metrics_users.select(:id)
    end

    def cards
      opened_today, climbed_today = today_engagement_counts

      {
        users_total: metrics_users.count,
        users_week: metrics_users.where(created_at: 7.days.ago.beginning_of_day..).count,
        users_month: metrics_users.where(created_at: @today.beginning_of_month.beginning_of_day..).count,
        opened_today: opened_today,
        climbed_today: climbed_today,
        battles_completed: completed_battles_count,
        projects_completed: StrategyGoal.for_kind("project")
                                          .where(user_id: metrics_user_ids)
                                          .where.not(completed_at: nil)
                                          .count,
        onboarding_done: metrics_users.where.not(onboarding_completed_at: nil).count,
        onboarding_pending: metrics_users.where(onboarding_completed_at: nil).count
      }
    end

    def charts
      {
        users_per_day: series_for(metrics_users, :created_at),
        life_points_per_day: ledger_series,
        battles_per_day: battle_series
      }
    end

    def today_engagement_counts
      rows = metrics_users.left_joins(:notification_preference).pluck(
        "users.id",
        "users.last_opened_on",
        "notification_preferences.time_zone"
      )

      opened_today_entries = rows.filter_map do |user_id, last_opened_on, time_zone|
        next if last_opened_on.blank?

        zone_stub = Struct.new(:notification_preference).new(Struct.new(:time_zone).new(time_zone))
        zone_name = Battles::WinsOnLocalDate.time_zone_for(zone_stub)
        local_today = Battles::WinsOnLocalDate.local_today_for(zone_stub)
        next unless last_opened_on == local_today

        [ user_id, local_today, zone_name ]
      end

      users_by_id = User.where(id: opened_today_entries.map(&:first)).index_by(&:id)
      climbed_today = opened_today_entries.count do |user_id, local_today, zone_name|
        user = users_by_id[user_id]
        next false unless user

        Battles::WinsOnLocalDate.count_for_date(
          user: user,
          date: local_today,
          time_zone: zone_name
        ).positive?
      end

      [ opened_today_entries.size, climbed_today ]
    end

    def completed_battles_count
      Mission.where(user_id: metrics_user_ids).where.not(completed_at: nil).count +
        DailyTodo.where(user_id: metrics_user_ids).where.not(completed_at: nil).count +
        StrategyGoal.battles.where(user_id: metrics_user_ids).where.not(completed_at: nil).count
    end

    def series_for(scope, column)
      rows = scope.where(column => @range_start.beginning_of_day..).group(Arel.sql("date(#{column})")).count
      fill_days(rows)
    end

    def ledger_series
      rows = LifePointLedger.where(user_id: metrics_user_ids)
                            .where(created_at: @range_start.beginning_of_day..)
                            .where("amount > 0")
                            .group(Arel.sql("date(created_at)"))
                            .sum(:amount)
      fill_days(rows)
    end

    def battle_series
      mission_rows = Mission.where(user_id: metrics_user_ids)
                            .where.not(completed_at: nil)
                            .where(completed_at: @range_start.beginning_of_day..)
                            .group(Arel.sql("date(completed_at)")).count
      todo_rows = DailyTodo.where(user_id: metrics_user_ids)
                           .where.not(completed_at: nil)
                           .where(completed_at: @range_start.beginning_of_day..)
                           .group(Arel.sql("date(completed_at)")).count
      day_rows = StrategyGoal.battles.where(user_id: metrics_user_ids)
                             .where.not(completed_at: nil)
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
