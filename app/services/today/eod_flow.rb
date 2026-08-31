# frozen_string_literal: true

module Today
  # Resolves the sequential end-of-day step from session + gate state.
  class EodFlow
    ACK_SESSION_KEY = :today_eod_acknowledged

    STEPS = %i[hidden win plan closed].freeze
    PLAN_EVENING_HOUR = 18

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

    # Before 6pm local: today framing; from 6pm: tomorrow framing.
    def self.plan_copy(user:, at: Time.current)
      evening_planning?(user: user, at: at) ? :tomorrow : :today
    end

    def self.plan_action_order(user:, at: Time.current)
      if evening_planning?(user: user, at: at)
        %i[tomorrow today]
      else
        %i[today tomorrow]
      end
    end

    def self.evening_planning?(user:, at: Time.current)
      local_time_for(user: user, at: at).hour >= PLAN_EVENING_HOUR
    end

    def self.local_time_for(user:, at: Time.current)
      zone = user.notification_preference&.time_zone.presence || Time.zone.name
      at.in_time_zone(zone)
    rescue ArgumentError, TZInfo::InvalidTimezoneIdentifier
      at.in_time_zone(Time.zone)
    end
  end
end
