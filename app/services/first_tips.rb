# frozen_string_literal: true

# Chooses the next first-time tip for onboarding v3 users (data layer; UI in slice 2).
module FirstTips
  CHAIN = %w[circle mountain camp camp_sheet you_tab habit animal].freeze

  PAGE_FOR = {
    "circle" => :today,
    "mountain" => :today,
    "camp" => :mountain,
    "camp_sheet" => :mountain,
    "you_tab" => :mountain,
    "habit" => :today,
    "animal" => :you
  }.freeze

  class << self
    def next_tip_for(user:, page:, context:)
      return nil if user.blank?
      return nil if context.read_only_impersonation

      journey = user.primary_focused_journey
      return nil unless journey&.onboarding_v3?
      return nil if context.blocked_by_overlays?

      CHAIN.each do |key|
        next if user.first_tip_seen?(key)
        next unless PAGE_FOR[key] == page.to_sym
        next unless eligible?(user, key, context)

        return Presenter.config_for(key)
      end

      nil
    end

    private

    def eligible?(user, key, context)
      case key
      when "circle"
        circle_eligible?(user, context)
      when "mountain"
        mountain_eligible?(user, context)
      when "camp"
        camp_eligible?(user)
      when "camp_sheet"
        camp_sheet_eligible?(user)
      when "you_tab"
        you_tab_eligible?(user)
      when "habit"
        habit_eligible?(user)
      when "animal"
        animal_eligible?(user)
      else
        false
      end
    end

    def circle_eligible?(user, context)
      context.open_battles? && !user.battle_won_once?
    end

    def mountain_eligible?(user, _context)
      return false unless user.battle_won_once?

      user.first_tip_seen?("circle") || !circle_still_possible?(user)
    end

    def circle_still_possible?(user)
      !user.battle_won_once?
    end

    def camp_eligible?(user)
      user.first_tip_seen?("mountain")
    end

    def camp_sheet_eligible?(user)
      user.first_tip_seen?("camp")
    end

    def you_tab_eligible?(user)
      user.first_tip_seen?("camp_sheet")
    end

    def habit_eligible?(user)
      day_index = user.onboarding_local_day_index
      return false if day_index.nil? || day_index < 1

      !user.habits.active.on_home.exists?
    end

    def animal_eligible?(user)
      user.first_tip_seen?("you_tab")
    end
  end
end
