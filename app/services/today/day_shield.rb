# frozen_string_literal: true

module Today
  # Once-per-day shield that blocks a single missed-window AP loss.
  class DayShield
    Status = Struct.new(:available, :date, keyword_init: true)

    def self.reconcile!(user:, date: Date.current)
      new(user:, date:).reconcile!
    end

    def self.available?(user:, date: Date.current)
      new(user:, date:).available?
    end

    def self.consume!(user:, date: Date.current)
      new(user:, date:).consume!
    end

    def self.status(user:, date: Date.current)
      new(user:, date:).status
    end

    def initialize(user:, date: Date.current)
      @user = user
      @date = date
    end

    def reconcile!
      unless @user.day_shield_on == @date
        @user.update!(day_shields_available: 1, day_shield_on: @date)
      end
      status_snapshot
    end

    def available?
      reconcile!
      @user.day_shields_available.to_i.positive?
    end

    def consume!
      reconcile!
      return false unless @user.day_shields_available.to_i.positive?

      @user.update!(day_shields_available: 0)
      true
    end

    def status
      reconcile!
    end

    private

    def status_snapshot
      Status.new(available: @user.day_shields_available.to_i.positive?, date: @date)
    end
  end
end
