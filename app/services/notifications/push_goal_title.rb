# frozen_string_literal: true

module Notifications
  # Truncate goal names for push titles without splitting emoji or combining marks.
  class PushGoalTitle
    ELLIPSIS = "…"

    def self.truncate(text, limit: 40)
      new(text, limit: limit).truncate
    end

    def initialize(text, limit: 40)
      @text = text.to_s
      @limit = limit.to_i
    end

    def truncate
      return @text if @limit <= 0

      clusters = @text.each_grapheme_cluster.to_a
      return @text if clusters.size <= @limit

      clusters.take(@limit).join + ELLIPSIS
    end
  end
end
