# frozen_string_literal: true

module Admin
  # Beta-tester triage rows for Mareks and Karen.
  # Product wins only (Battles::WinsOnLocalDate sources) — never the broader funnel.
  class Testers
    STALE_AFTER_DAYS = 3
    RECURRING_REPEATS = Battles::WinsOnLocalDate::RECURRING_REPEATS
    FILTER_NEEDS_MESSAGE = "needs_message"
    FILTER_EVERYONE = "everyone"
    FILTERS = [ FILTER_NEEDS_MESSAGE, FILTER_EVERYONE ].freeze
    PLAY_TESTERS_URL =
      "https://play.google.com/console/u/0/developers/7962663201417265259/app/4975708625747728285/tracks/4699763347313539783?tab=testers"

    Row = Data.define(
      :user,
      :contact,
      :signed_up_at,
      :onboarding_done,
      :first_win_at,
      :last_win_at,
      :wins_this_week,
      :last_opened_on,
      :days_since_open,
      :push_on,
      :partner,
      :reason_key,
      :reason,
      :days_since_last_win
    )

    def self.call(filter: FILTER_NEEDS_MESSAGE)
      new(filter: filter).call
    end

    def initialize(filter: FILTER_NEEDS_MESSAGE)
      @filter = FILTERS.include?(filter.to_s) ? filter.to_s : FILTER_NEEDS_MESSAGE
    end

    def call
      rows = sort_rows(build_rows)
      return rows if @filter == FILTER_EVERYONE

      rows.select { |row| needs_message?(row) }
    end

    private

    def build_rows
      users = User.excluding_privileged.order(:id).to_a
      return [] if users.empty?

      user_ids = users.map(&:id)
      contacts = TesterContact.where(user_id: user_ids).index_by(&:user_id)
      first_wins = merge_times(
        one_shot_battles(user_ids).group(:user_id).minimum(:completed_at),
        recurring_todos(user_ids).group(:user_id).minimum(:completed_at),
        :min
      )
      last_wins = merge_times(
        one_shot_battles(user_ids).group(:user_id).maximum(:completed_at),
        recurring_todos(user_ids).group(:user_id).maximum(:completed_at),
        :max
      )
      week_wins = merge_counts(
        one_shot_battles(user_ids).where(completed_at: week_range).group(:user_id).count,
        recurring_todos(user_ids).where(completed_at: week_range).group(:user_id).count
      )
      push_ids = PushSubscription.where(user_id: user_ids).distinct.pluck(:user_id).to_set
      partner_ids = partner_user_ids(user_ids)

      users.map do |user|
        first_win_at = first_wins[user.id]
        last_win_at = last_wins[user.id]
        days_since_last_win = days_since(last_win_at&.to_date)
        reason_key = reason_key_for(
          onboarding_done: user.onboarding_completed_at.present?,
          last_win_at: last_win_at,
          days_since_last_win: days_since_last_win
        )

        Row.new(
          user: user,
          contact: contacts[user.id],
          signed_up_at: user.created_at,
          onboarding_done: user.onboarding_completed_at.present?,
          first_win_at: first_win_at,
          last_win_at: last_win_at,
          wins_this_week: week_wins[user.id].to_i,
          last_opened_on: user.last_opened_on,
          days_since_open: days_since(user.last_opened_on),
          push_on: push_ids.include?(user.id),
          partner: partner_ids.include?(user.id),
          reason_key: reason_key,
          reason: reason_label(reason_key, days_since_last_win),
          days_since_last_win: days_since_last_win
        )
      end
    end

    def needs_message?(row)
      return false if row.reason_key.blank?

      contact = row.contact
      return true if contact.nil?

      !contact.contacted_recently?
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

    def partner_user_ids(user_ids)
      rows = ClimbPartnership.active
        .where(inviter_id: user_ids)
        .or(ClimbPartnership.active.where(invitee_id: user_ids))
        .pluck(:inviter_id, :invitee_id)

      ids = Set.new
      rows.each do |inviter_id, invitee_id|
        ids << inviter_id if user_ids.include?(inviter_id)
        ids << invitee_id if invitee_id.present? && user_ids.include?(invitee_id)
      end
      ids
    end

    def days_since(date)
      return nil if date.blank?

      (Date.current - date).to_i
    end

    def reason_key_for(onboarding_done:, last_win_at:, days_since_last_win:)
      return :onboarding unless onboarding_done
      return :never_won if last_win_at.blank?
      return :stale if days_since_last_win.to_i >= STALE_AFTER_DAYS

      nil
    end

    def reason_label(reason_key, days_since_last_win)
      case reason_key
      when :onboarding
        I18n.t("admin.testers.reason.onboarding")
      when :never_won
        I18n.t("admin.testers.reason.never_won")
      when :stale
        I18n.t("admin.testers.reason.stale", count: days_since_last_win.to_i)
      end
    end

    def sort_rows(rows)
      rows.sort_by do |row|
        rank = reason_rank(row.reason_key)
        stale_days = row.days_since_last_win.to_i
        last_win_sort = row.last_win_at ? -row.last_win_at.to_i : 0
        [
          rank,
          (rank == 2 ? -stale_days : 0),
          (rank == 3 ? last_win_sort : 0),
          -row.signed_up_at.to_i,
          row.user.id
        ]
      end
    end

    def reason_rank(reason_key)
      case reason_key
      when :onboarding then 0
      when :never_won then 1
      when :stale then 2
      else 3
      end
    end
  end
end
