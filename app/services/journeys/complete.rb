# frozen_string_literal: true

module Journeys
  class Complete
    class Error < StandardError; end

    COMPLETION_LP = 250

    def self.call(user:, journey:)
      new(user:, journey:).call
    end

    def initialize(user:, journey:)
      @user = user
      @journey = journey
    end

    def call
      raise Error, "Journey not found" unless @journey
      raise Error, "Not your journey" unless @journey.user_id == @user.id
      return @journey if @journey.status == "completed"

      ActiveRecord::Base.transaction do
        @journey.update_columns(
          status: "completed",
          focus_position: nil,
          completed_at: Time.current,
          gap_percent: [ @journey.gap_percent.to_f, 5.0 ].min,
          updated_at: Time.current
        )
        @journey.reload
        LifePoints::Award.call(
          user: @user,
          amount: COMPLETION_LP,
          reason: I18n.t("journeys.completion_lp_reason", title: @journey.title),
          source: @journey
        )
        @journey
      end
    end
  end
end
