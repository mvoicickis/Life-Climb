# frozen_string_literal: true

module Admin
  # Compare Play closed-test emails with signed-up users for admin invite triage.
  class BetaTestersRoster
    RECURRING_REPEATS = Battles::WinsOnLocalDate::RECURRING_REPEATS
    TIER_RECENT_WIN = 1
    TIER_NEVER_WON = 2
    TIER_OTHER = 3

    NotTesterRow = Data.define(:user, :tier, :last_win_at)
    TesterRow = Data.define(
      :beta_tester,
      :user,
      :last_opened_on,
      :wins_this_week,
      :play_app
    )
    NoAccountRow = Data.define(:beta_tester)

    def self.call
      new.call
    end

    def call
      tester_emails = BetaTester.pluck(:email).to_set
      users = User.excluding_privileged.to_a
      user_ids = users.map(&:id)
      device_profiles = Testers.device_profiles_for(user_ids)
      last_wins = last_wins_by_user(user_ids)
      week_wins = wins_this_week_by_user(user_ids)
      recent_cutoff = 7.days.ago

      not_testers = users.filter_map do |user|
        profile = device_profiles[user.id] || {}
        next unless profile[:primary] == DeviceFromUserAgent::DEVICE_ANDROID
        next if tester_emails.include?(user.email_address)

        last_win_at = last_wins[user.id]
        tier = tier_for(last_win_at, recent_cutoff)

        NotTesterRow.new(user: user, tier: tier, last_win_at: last_win_at)
      end
      not_testers.sort_by! { |row| sort_key_not_tester(row) }

      testers_with_account = BetaTester.where.not(user_id: nil).includes(:user).order(added_at: :desc)
      testers = testers_with_account.map do |beta_tester|
        user = beta_tester.user
        TesterRow.new(
          beta_tester: beta_tester,
          user: user,
          last_opened_on: user.last_opened_on,
          wins_this_week: week_wins[user.id].to_i,
          play_app: user.play_app_seen_at.present?
        )
      end

      no_account = BetaTester.where(user_id: nil).order(added_at: :desc).map do |beta_tester|
        NoAccountRow.new(beta_tester: beta_tester)
      end

      {
        not_testers: not_testers,
        testers: testers,
        no_account: no_account
      }
    end

    private

    def tier_for(last_win_at, recent_cutoff)
      return TIER_NEVER_WON if last_win_at.blank?
      return TIER_RECENT_WIN if last_win_at >= recent_cutoff

      TIER_OTHER
    end

    def sort_key_not_tester(row)
      activity = activity_timestamp(row.user, row.last_win_at)
      [ row.tier, -activity.to_i, -row.user.created_at.to_i, row.user.id ]
    end

    def activity_timestamp(user, last_win_at)
      candidates = [ last_win_at, user.last_opened_on&.in_time_zone&.end_of_day, user.created_at ].compact
      candidates.max
    end

    def last_wins_by_user(user_ids)
      merge_times(
        one_shot_battles(user_ids).group(:user_id).maximum(:completed_at),
        recurring_todos(user_ids).group(:user_id).maximum(:completed_at),
        :max
      )
    end

    def wins_this_week_by_user(user_ids)
      merge_counts(
        one_shot_battles(user_ids).where(completed_at: week_range).group(:user_id).count,
        recurring_todos(user_ids).where(completed_at: week_range).group(:user_id).count
      )
    end

    def one_shot_battles(user_ids)
      StrategyGoal.battles
        .where(user_id: user_ids)
        .where.not(repeat: RECURRING_REPEATS)
        .where.not(completed_at: nil)
    end

    def recurring_todos(user_ids)
      DailyTodo.where(user_id: user_ids)
        .where.not(completed_at: nil)
        .joins(:strategy_goal)
        .where(strategy_goals: { repeat: RECURRING_REPEATS })
    end

    def week_range
      start = Time.current.beginning_of_week(:monday)
      finish = start.end_of_week(:monday)
      start..finish
    end

    def merge_times(left, right, mode)
      merged = {}
      [ left, right ].each do |rows|
        rows.each do |user_id, timestamp|
          next if timestamp.blank?

          merged[user_id] =
            if merged[user_id].blank?
              timestamp
            elsif mode == :min
              [ merged[user_id], timestamp ].min
            else
              [ merged[user_id], timestamp ].max
            end
        end
      end
      merged
    end

    def merge_counts(left, right)
      merged = Hash.new(0)
      left.each { |user_id, count| merged[user_id] += count.to_i }
      right.each { |user_id, count| merged[user_id] += count.to_i }
      merged
    end
  end
end
