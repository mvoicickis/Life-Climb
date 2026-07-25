# frozen_string_literal: true

module LifePoints
  # Sole LP writer for planning_version 2 mission completions.
  class Award
    def self.call(user:, amount:, reason:, source:)
      new(user).call(amount:, reason:, source:)
    end

    def initialize(user)
      @user = user
    end

    def call(amount:, reason:, source:)
      raise "v2 LP awards only" unless @user.planning_v2?

      LifePointsAward.new(@user).award!(amount: amount, reason: reason, source: source)
    end
  end
end
