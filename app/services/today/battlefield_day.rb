# frozen_string_literal: true

module Today
  # Session flag: user tapped "End day" on Today V2 battlefield.
  class BattlefieldDay
    SESSION_KEY = :today_battlefield_day_ended

    def self.ended?(session)
      session[SESSION_KEY].to_s == Date.current.to_s
    end

    def self.end!(session)
      session[SESSION_KEY] = Date.current.to_s
    end

    def self.reset!(session)
      session.delete(SESSION_KEY)
    end
  end
end
