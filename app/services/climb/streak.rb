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
      on = streak_on
      days = streak_days

      if on == today
        return Result.new(days: days, changed: false, earned_freeze: false, reset: false)
      end

      new_days =
        if on == today - 1 || (frozen_on == today - 1 && days.positive?)
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
      if freezes_ready? && FREEZE_MILESTONES.include?(new_days)
        freezes = streak_freezes
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
      on = streak_on
      days = streak_days
      freezes = streak_freezes

      return ReconcileResult.new(days: days, consumed_freeze: false, reset: false) if on.blank? || days <= 0
      return ReconcileResult.new(days: days, consumed_freeze: false, reset: false) if on >= today - 1

      gap_days = (today - on).to_i - 1
      # Only cover a single missed calendar day with one freeze (Duolingo-like).
      if freezes_ready? && gap_days == 1 && freezes.positive?
        @user.update!(
          climb_streak_freezes: freezes - 1,
          climb_streak_on: today - 1,
          climb_streak_frozen_on: today - 1
        )
        return ReconcileResult.new(days: days, consumed_freeze: true, reset: false)
      end

      attrs = { climb_streak_days: 0, climb_streak_on: nil }
      attrs[:climb_streak_frozen_on] = nil if freezes_ready?
      @user.update!(attrs)
      ReconcileResult.new(days: 0, consumed_freeze: false, reset: true)
    end

    def current
      status.days
    end

    def status
      today = Date.current
      on = streak_on
      days = streak_days
      freezes = streak_freezes
      frozen = frozen_on

      if on.blank? || days <= 0 || on < today - 1
        return Status.new(days: 0, freezes: freezes, frozen_recently: false, fresh_start: true)
      end

      Status.new(
        days: days,
        freezes: freezes,
        frozen_recently: frozen.present? && frozen >= today - 2,
        fresh_start: false
      )
    end

    private

    # Survive a deploy where code ships before migrate finishes (or migrate fails).
    def freezes_ready?
      @user.has_attribute?(:climb_streak_freezes) && @user.has_attribute?(:climb_streak_frozen_on)
    end

    def streak_days
      @user.climb_streak_days.to_i
    end

    def streak_on
      @user.climb_streak_on
    end

    def streak_freezes
      return 0 unless freezes_ready?

      @user.climb_streak_freezes.to_i
    end

    def frozen_on
      return nil unless freezes_ready?

      @user.climb_streak_frozen_on
    end
  end
end
