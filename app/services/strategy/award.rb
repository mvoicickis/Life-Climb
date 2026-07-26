# frozen_string_literal: true

module Strategy
  class Award
    def self.call(user:, amount:, reason:, source: nil)
      new(user).call(amount:, reason:, source:)
    end

    def initialize(user)
      @user = user
    end

    def call(amount:, reason:, source: nil)
      amount = amount.to_i
      return if amount.zero?

      ActiveRecord::Base.transaction do
        attrs = { amount: amount, reason: reason }
        attrs[:source] = source if source
        @user.strategy_point_ledgers.create!(attrs)
        @user.update!(strategy_points: @user.strategy_points + amount)
      end
    end
  end
end
