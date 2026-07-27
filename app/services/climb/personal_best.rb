# frozen_string_literal: true

module Climb
  # Self-only personal best for a single day's Action Points.
  class PersonalBest
    Result = Struct.new(:best, :new_record, keyword_init: true)

    def self.record!(user:, awarded:)
      new(user:).record!(awarded: awarded)
    end

    def self.best(user:)
      user.best_day_ap.to_i
    end

    def initialize(user:)
      @user = user
    end

    def record!(awarded:)
      amount = awarded.to_i
      return Result.new(best: @user.best_day_ap.to_i, new_record: false) if amount <= 0

      today_total = todays_ap_earned
      previous_best = @user.best_day_ap.to_i
      # today_total already includes this award if ledger was written first.
      candidate = [ today_total, amount ].max

      if candidate > previous_best
        @user.update!(best_day_ap: candidate)
        Result.new(best: candidate, new_record: previous_best.positive?)
      else
        Result.new(best: previous_best, new_record: false)
      end
    end

    private

    def todays_ap_earned
      @user.life_point_ledgers.where("amount > 0").where(created_at: Time.current.beginning_of_day..).sum(:amount).to_i
    end
  end
end
