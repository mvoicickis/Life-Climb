# frozen_string_literal: true

module Habits
  # Two quick-add deltas sized to a habit's daily target (mockup steps()).
  class QuickAddSteps
    def self.call(target:)
      new(target: target).call
    end

    def initialize(target:)
      @target = target
    end

    def call
      t = normalize(@target)
      return [ 1, 5 ] if t.nil?

      steps =
        if t <= 3
          [ 1, t ]
        elsif t <= 10
          [ 1, 5 ]
        elsif t <= 50
          half = ((t / 2.0) / 5.0).round * 5
          [ 5, half.positive? ? half : 5 ]
        elsif t <= 200
          [ 10, 50 ]
        elsif t <= 2000
          [ 50, 250 ]
        else
          [ 500, 2000 ]
        end

      steps.uniq
    end

    private

    def normalize(raw)
      return nil if raw.blank?

      n = BigDecimal(raw.to_s)
      return nil if n <= 0

      n.to_i
    rescue ArgumentError
      nil
    end
  end
end
