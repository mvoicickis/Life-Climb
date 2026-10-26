# frozen_string_literal: true

module Today
  # Once-per-local-day celebration after the first strategy-battle win of the day,
  # when Battles::DaysInARow is at least 2. Marks users.last_streak_moment_on.
  # Extends to progress / goal when a streak commitment is active.
  class StreakMoment
    Result = Struct.new(
      :kind,
      :days,
      :from_days,
      :week,
      :goal_title,
      :target_days,
      :fill_pct,
      :offer_commit,
      :offered_targets,
      :default_target,
      keyword_init: true
    )

    def self.eligible?(user:)
      new(user:).eligible?
    end

    def self.present_for!(user:, goal_title:)
      new(user:).present_for!(goal_title: goal_title)
    end

    def initialize(user:)
      @user = user
      @commitment = StreakCommitment.for(user)
    end

    def eligible?
      return false if read_only?

      # Quiet-reset must run even when we will not present (days < 2).
      @commitment.sync!

      today = local_today
      return false if @user.last_streak_moment_on == today
      return false if Battles::DaysInARow.count(user: @user) < 2

      won_today?
    end

    def present_for!(goal_title:)
      return nil if read_only?

      # Quiet-reset before the days ≥ 2 gate so broken commitments clear.
      @commitment.sync!

      today = local_today
      return nil if @user.last_streak_moment_on == today

      days = Battles::DaysInARow.count(user: @user)
      return nil if days < 2
      return nil unless won_today?

      week = Stats::BattleWins.call(user: @user).this_week
      target = @commitment.target_days
      kind = kind_for(days: days, target: target)
      offered = @commitment.offered_targets(days_in_a_row: days)
      offer_commit = kind == :celebrate && @commitment.can_offer?(days_in_a_row: days)
      # Goal card may open Pick your climb for a bigger target; same offer list.
      show_targets = offer_commit || (kind == :goal && offered.any? && @commitment.declines < 2)
      fill_pct = fill_pct_for(days: days, target: target)

      @user.update!(last_streak_moment_on: today)

      result = Result.new(
        kind: kind,
        days: days,
        from_days: [ days - 1, 1 ].max,
        week: week,
        goal_title: goal_title.to_s,
        target_days: target,
        fill_pct: fill_pct,
        offer_commit: offer_commit,
        offered_targets: show_targets ? offered : [],
        default_target: show_targets ? @commitment.default_target(offered) : nil
      )

      # Goal shows once: clear commitment in the same request after building the result.
      @commitment.clear! if kind == :goal

      result
    end

    private

    def kind_for(days:, target:)
      return :celebrate if target.blank?
      return :goal if days >= target

      :progress
    end

    def fill_pct_for(days:, target:)
      return 0 if target.blank? || target.to_i <= 0

      [ ((days.to_f * 100.0) / target.to_i).round, 100 ].min
    end

    def local_today
      Battles::WinsOnLocalDate.local_today_for(@user)
    end

    def won_today?
      zone = Battles::WinsOnLocalDate.time_zone_for(@user)
      Battles::WinsOnLocalDate.count_for_date(
        user: @user,
        date: local_today,
        time_zone: zone
      ).positive?
    end

    def read_only?
      # Survive a deploy where code ships before migrate finishes.
      !@user.has_attribute?(:last_streak_moment_on) || @commitment.read_only?
    end
  end
end
