# frozen_string_literal: true

module Admin
  # Per-user funnel rows from existing data — one bulk build, many presentations.
  class UserFunnel
    Row = Data.define(
      :user,
      :signed_up_at,
      :onboarding_completed_at,
      :first_camp_planted_at,
      :first_battle_won_at,
      :returned_second_day_at,
      :last_seen_at
    )

    INACTIVE_AFTER = 3.days
    FILTER_INACTIVE = "inactive"

    def self.call(sort: "last_seen", filter: nil)
      new(sort:, filter:).call
    end

    def self.export_csv(rows)
      require "csv"
      CSV.generate(headers: true) do |csv|
        csv << %w[
          id name email signed_up_at onboarding_completed_at first_camp_planted_at
          first_battle_won_at returned_second_day_at last_seen_at
        ]
        rows.each do |row|
          csv << [
            row.user.id,
            row.user.name,
            row.user.email_address,
            row.signed_up_at&.iso8601,
            row.onboarding_completed_at&.iso8601,
            row.first_camp_planted_at&.iso8601,
            row.first_battle_won_at&.iso8601,
            row.returned_second_day_at&.iso8601,
            row.last_seen_at&.iso8601
          ]
        end
      end
    end

    def initialize(sort:, filter:)
      @sort = sort
      @filter = filter
    end

    def call
      rows = build_rows
      {
        stage_counts: stage_counts_from(rows),
        rows: apply_filter(sort_rows(rows), @filter)
      }
    end

    private

    def build_rows
      users = User.excluding_privileged.order(:id).to_a
      return [] if users.empty?

      user_ids = users.map(&:id)
      first_camps = StrategyGoal.for_kind("project").not_holding.where(user_id: user_ids).group(:user_id).minimum(:created_at)
      first_battles = first_battle_by_user(user_ids)
      last_seen = Session.where(user_id: user_ids).group(:user_id).maximum(:updated_at)
      second_days = second_activity_day_by_user(user_ids)

      users.map do |user|
        Row.new(
          user:,
          signed_up_at: user.created_at,
          onboarding_completed_at: user.onboarding_completed_at,
          first_camp_planted_at: first_camps[user.id],
          first_battle_won_at: first_battles[user.id],
          returned_second_day_at: second_days[user.id],
          last_seen_at: last_seen[user.id]
        )
      end
    end

    def first_battle_by_user(user_ids)
      sources = [
        Mission.where(user_id: user_ids).where.not(completed_at: nil).group(:user_id).minimum(:completed_at),
        DailyTodo.where(user_id: user_ids).where.not(completed_at: nil).group(:user_id).minimum(:completed_at),
        StrategyGoal.battles.where(user_id: user_ids).where.not(completed_at: nil).group(:user_id).minimum(:completed_at)
      ]

      merged = {}
      sources.each do |rows|
        rows.each do |user_id, completed_at|
          next if completed_at.blank?

          merged[user_id] = [ merged[user_id], completed_at ].compact.min
        end
      end
      merged
    end

    def second_activity_day_by_user(user_ids)
      day_rows = Session.where(user_id: user_ids)
                        .group(:user_id, Arel.sql("date(updated_at)"))
                        .minimum(:updated_at)

      by_user = Hash.new { |hash, key| hash[key] = [] }
      day_rows.each do |(user_id, _day), timestamp|
        by_user[user_id] << timestamp
      end

      by_user.transform_values do |timestamps|
        sorted = timestamps.sort
        sorted[1] if sorted.size >= 2
      end
    end

    def stage_counts_from(rows)
      {
        signed_up: rows.size,
        onboarding_complete: rows.count { |row| row.onboarding_completed_at.present? },
        first_camp_planted: rows.count { |row| row.first_camp_planted_at.present? },
        first_battle_won: rows.count { |row| row.first_battle_won_at.present? },
        returned_second_day: rows.count { |row| row.returned_second_day_at.present? }
      }
    end

    def sort_rows(rows)
      case @sort.to_s
      when "last_seen_asc"
        rows.sort_by { |row| [ row.last_seen_at.nil? ? 1 : 0, row.last_seen_at || Time.at(0), row.user.id ] }
      else
        rows.sort_by { |row| [ row.last_seen_at.nil? ? 1 : 0, row.last_seen_at ? -row.last_seen_at.to_i : 0, -row.user.id ] }
      end
    end

    def apply_filter(rows, filter)
      return rows unless filter.to_s == FILTER_INACTIVE

      cutoff = INACTIVE_AFTER.ago
      rows.select { |row| row.last_seen_at.blank? || row.last_seen_at < cutoff }
    end
  end
end
