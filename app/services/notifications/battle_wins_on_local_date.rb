# frozen_string_literal: true

module Notifications
  # Calendar-day battle wins in the user's time zone — not Mountain "done today".
  class BattleWinsOnLocalDate
    def self.any?(user:, date:, time_zone:)
      Battles::WinsOnLocalDate.count_for_date(user: user, date: date, time_zone: time_zone).positive?
    end
  end
end
