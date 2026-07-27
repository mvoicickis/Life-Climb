# frozen_string_literal: true

module Climb
  # Soft consecutive-day climb streak. Quiet reset — no shame copy.
  class Streak
    Result = Struct.new(:days, :changed, keyword_init: true)

    def self.touch!(user:)
      new(user:).touch!
    end

    def self.current(user:)
      new(user:).current
    end

    def initialize(user:)
      @user = user
    end

    def touch!
      today = Date.current
      on = @user.climb_streak_on
      days = @user.climb_streak_days.to_i

      if on == today
        return Result.new(days: days, changed: false)
      end

      new_days =
        if on == today - 1
          days + 1
        else
          1
        end

      @user.update!(climb_streak_days: new_days, climb_streak_on: today)
      Result.new(days: new_days, changed: true)
    end

    def current
      today = Date.current
      on = @user.climb_streak_on
      days = @user.climb_streak_days.to_i
      return 0 if on.blank? || days <= 0
      return 0 if on < today - 1

      days
    end
  end
end
