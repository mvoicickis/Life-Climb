# frozen_string_literal: true

module Today
  # Persist a streak climb target (3/7/14/30 days). Active only while DaysInARow ≥ 2.
  # Broken commitments (target set, streak < 2) clear target + started_on lazily on read.
  class StreakCommitment
    TARGETS = [ 3, 7, 14, 30 ].freeze

    def self.for(user)
      new(user)
    end

    # Read-only view for push copy. Never sync!/clear!/update!.
    # Returns { target:, n: } or nil.
    def self.peek(user, date: nil)
      new(user).peek(date: date)
    end

    def initialize(user)
      @user = user
    end

    def read_only?
      !(
        @user.has_attribute?(:streak_commitment_target_days) &&
        @user.has_attribute?(:streak_commitment_started_on) &&
        @user.has_attribute?(:streak_commit_declines)
      )
    end

    # Push-safe: target present and DaysInARow ≥ 2. Does not write.
    def peek(date: nil)
      return nil if read_only?

      target = @user.streak_commitment_target_days
      return nil if target.blank?

      streak = Battles::DaysInARow.count(user: @user)
      return nil if streak < 2

      zone = Battles::WinsOnLocalDate.time_zone_for(@user)
      on = date || Battles::WinsOnLocalDate.local_today_for(@user)
      won_today = Notifications::BattleWinsOnLocalDate.any?(
        user: @user,
        date: on,
        time_zone: zone
      )
      n = won_today ? streak : streak + 1
      n = [ n, target.to_i ].min

      { target: target.to_i, n: n }
    end

    # Clear broken commitment wherever commitment is read.
    def sync!
      return self if read_only?
      return self if @user.streak_commitment_target_days.blank?

      days = Battles::DaysInARow.count(user: @user)
      clear! if days < 2
      self
    end

    def active?
      sync!
      return false if read_only?
      return false if @user.streak_commitment_target_days.blank?

      Battles::DaysInARow.count(user: @user) >= 2
    end

    def target_days
      sync!
      @user.streak_commitment_target_days
    end

    def declines
      return 0 if read_only?

      @user.streak_commit_declines.to_i
    end

    def offered_targets(days_in_a_row:)
      TARGETS.select { |days| days > days_in_a_row.to_i }
    end

    def default_target(offered)
      list = Array(offered)
      return nil if list.empty?
      return 7 if list.include?(7)

      list.min
    end

    def can_offer?(days_in_a_row:)
      return false if read_only?
      return false if declines >= 2
      return false if active?

      offered_targets(days_in_a_row: days_in_a_row).any?
    end

    def commit!(days:, on:)
      return false if read_only?

      target = days.to_i
      current = Battles::DaysInARow.count(user: @user)
      return false unless offered_targets(days_in_a_row: current).include?(target)

      @user.update!(
        streak_commitment_target_days: target,
        streak_commitment_started_on: on
      )
      true
    end

    def decline!
      return false if read_only?

      next_count = [ declines + 1, 2 ].min
      @user.update!(streak_commit_declines: next_count)
      true
    end

    def clear!
      return false if read_only?
      return true if @user.streak_commitment_target_days.nil? && @user.streak_commitment_started_on.nil?

      @user.update!(
        streak_commitment_target_days: nil,
        streak_commitment_started_on: nil
      )
      true
    end

    def reminder_eligible?
      return false if read_only?

      @user.push_offer_permission_denied_at.blank?
    end
  end
end
