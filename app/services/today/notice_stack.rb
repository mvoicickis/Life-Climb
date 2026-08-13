# frozen_string_literal: true

module Today
  # Caps how many notices render between the Today hero and habits.
  # Eligibility is unchanged — deferred notices simply wait for a later visit
  # (except human_win, which is flash-only and therefore ranked high).
  #
  # Priority:
  # 1. next_action — always included when present (guides the day)
  # 2. human_win — one-shot flash; skipping loses it forever
  # 3. level_up — actionable commitment upgrade
  # 4. shield_tip — one-time tip; still eligible next visit
  # 5. install_offer — lowest; still eligible next visit
  class NoticeStack
    LIMIT = 2
    SECONDARY = %i[human_win level_up shield_tip install_offer].freeze

    def self.call(next_action:, human_win:, level_up:, shield_tip:, install_offer:)
      new(
        next_action: next_action,
        human_win: human_win,
        level_up: level_up,
        shield_tip: shield_tip,
        install_offer: install_offer
      ).call
    end

    def initialize(next_action:, human_win:, level_up:, shield_tip:, install_offer:)
      @flags = {
        next_action: next_action,
        human_win: human_win,
        level_up: level_up,
        shield_tip: shield_tip,
        install_offer: install_offer
      }
    end

    def call
      shown = []
      shown << :next_action if @flags[:next_action]

      SECONDARY.each do |key|
        break if shown.size >= LIMIT
        shown << key if @flags[key]
      end

      shown
    end
  end
end
