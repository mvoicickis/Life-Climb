# frozen_string_literal: true

module Today
  # Resolves the sequential end-of-day step from session + gate state.
  class EodFlow
    ACK_SESSION_KEY = :today_eod_acknowledged

    STEPS = %i[hidden win plan closed].freeze

    def self.step(session:, end_of_day_ready:, day_closed:)
      return :closed if day_closed
      return :hidden unless end_of_day_ready
      return :win unless acknowledged?(session)

      :plan
    end

    def self.acknowledged?(session)
      session[ACK_SESSION_KEY].to_s == Date.current.to_s
    end

    def self.acknowledge!(session)
      session[ACK_SESSION_KEY] = Date.current.to_s
    end

    def self.reset_acknowledge!(session)
      session.delete(ACK_SESSION_KEY)
    end

    def self.takeover_active?(step)
      %i[win plan closed].include?(step)
    end

    def self.flow_active?(step)
      %i[win plan].include?(step)
    end
  end
end
