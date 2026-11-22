# frozen_string_literal: true

module Notifications
  class NudgeDashboardUrl
    def self.for(open_battle:)
      return "/dashboard" if open_battle.blank? || open_battle.daily_todo_id.blank?

      "/dashboard?battle=#{open_battle.daily_todo_id}"
    end
  end
end
