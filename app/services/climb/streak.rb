# frozen_string_literal: true

module Climb
  # Soft consecutive-day climb streak with Duolingo-style Base Camp freezes.
  # Missed days: silent freeze if available, otherwise quiet reset — never shame.
  class Streak
    FREEZE_CAP = 2
    FREEZE_MILESTONES = [ 7, 30 ].freeze

    Result = Struct.new(:days, :changed, :earned_freeze, :reset, keyword_init: true)
    Status = Struct.new(:days, :freezes, :frozen_recently, :fresh_start, keyword_init: true)
    ReconcileResult = Struct.new(:days, :consumed_freeze, :reset, keyword_init: true)

    def self.touch!(user:)
      new(user:).touch!
    end

    def self.current(user:)
      new(user:).current
    end

    def self.reconcile!(user:)
      new(user:).reconcile!
    end

    def self.status(user:)
      new(user:).status
    end

    def initialize(user:)
      @user = user
    end

    def touch!
      reconcile!
      today = Date.current
      on = @user.climb_streak_on
      days = @user.climb_streak_days.to_i

      if on == today
        return Result.new(days: days, changed: false, earned_freeze: false, reset: false)
      end

      new_days =
        if on == today - 1 || (@user.climb_streak_frozen_on == today - 1 && days.positive?)
          days + 1
        elsif on.blank? || days <= 0
          1
        else
          # Should be rare after reconcile; start fresh calmly.
          1
        end

      attrs = {
        climb_streak_days: new_days,
        climb_streak_on: today
      }
      earned = false
      if FREEZE_MILESTONES.include?(new_days)
        freezes = @user.climb_streak_freezes.to_i
        if freezes < FREEZE_CAP
          attrs[:climb_streak_freezes] = freezes + 1
          earned = true
        end
      end

      @user.update!(attrs)
      Result.new(days: new_days, changed: true, earned_freeze: earned, reset: false)
    end

    # Call on Today / Mountain load before reading status.
    def reconcile!
      today = Date.current
      on = @user.climb_streak_on
      days = @user.climb_streak_days.to_i
      freezes = @user.climb_streak_freezes.to_i

      return ReconcileResult.new(days: days, consumed_freeze: false, reset: false) if on.blank? || days <= 0
      return ReconcileResult.new(days: days, consumed_freeze: false, reset: false) if on >= today - 1

      gap_days = (today - on).to_i - 1
      # Only cover a single missed calendar day with one freeze (Duolingo-like).
      if gap_days == 1 && freezes.positive?
        @user.update!(
          climb_streak_freezes: freezes - 1,
          climb_streak_on: today - 1,
          climb_streak_frozen_on: today - 1
        )
        return ReconcileResult.new(days: days, consumed_freeze: true, reset: false)
      end

      @user.update!(
        climb_streak_days: 0,
        climb_streak_on: nil,
        climb_streak_frozen_on: nil
      )
      ReconcileResult.new(days: 0, consumed_freeze: false, reset: true)
    end

    def current
      status.days
    end

    def status
      today = Date.current
      on = @user.climb_streak_on
      days = @user.climb_streak_days.to_i
      freezes = @user.climb_streak_freezes.to_i
      frozen_on = @user.climb_streak_frozen_on

      if on.blank? || days <= 0 || on < today - 1
        return Status.new(days: 0, freezes: freezes, frozen_recently: false, fresh_start: true)
      end

      Status.new(
        days: days,
        freezes: freezes,
        frozen_recently: frozen_on.present? && frozen_on >= today - 2,
        fresh_start: false
      )
    end
  end
end
