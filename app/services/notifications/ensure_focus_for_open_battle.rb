# frozen_string_literal: true

module Notifications
  # Align focused journey with an open battle before a push — same as Today::FocusesController.
  class EnsureFocusForOpenBattle
    def self.call(user:, open_battle:)
      new(user: user, open_battle: open_battle).call
    end

    def initialize(user:, open_battle:)
      @user = user
      @open_battle = open_battle
    end

    def call
      return false if @open_battle.blank?
      return false if @open_battle.life_journey_id.blank?

      focused = @user.primary_focused_journey
      return false if focused&.id == @open_battle.life_journey_id

      Focus::SetJourneys.call(user: @user, journey_ids: [ @open_battle.life_journey_id ])
      true
    rescue Focus::SetJourneys::Error => e
      Rails.logger.warn(
        "[EnsureFocusForOpenBattle] skip user=#{@user.id} journey=#{@open_battle.life_journey_id} " \
        "#{e.class}: #{e.message}"
      )
      false
    end
  end
end
