# frozen_string_literal: true

module Habits
  # Single quick-add delta + four sheet suggestions, sized to a habit target
  # (mockup derived() / suggestions()).
  class QuickAdd
    def self.derived(target:)
      new(target: target).derived
    end

    def self.suggestions(target:)
      new(target: target).suggestions
    end

    def initialize(target:)
      @target = target
    end

    def derived
      t = normalize(@target)
      return 1 if t.nil? || t <= 3
      return 5 if t <= 50
      return 10 if t <= 200
      return 100 if t <= 2000

      1000
    end

    def suggestions
      t = normalize(@target)
      return [ 1, 2, 3, 5 ] if t.nil? || t <= 5
      return [ 1, 5, 10, 20 ] if t <= 20
      return [ 5, 10, 25, 50 ] if t <= 100
      return [ 50, 100, 250, 500 ] if t <= 2000

      [ 500, 1000, 2500, 5000 ]
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
