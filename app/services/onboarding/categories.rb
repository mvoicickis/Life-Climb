# frozen_string_literal: true

module Onboarding
  # Six visual categories for the first-time adventure picker.
  # Growth and Or else both map to the DB area key "purpose"; the category id
  # is kept separately so chip/example copy can still diverge.
  class Categories
    Entry = Data.define(:id, :area_key, :icon)

    ALL = [
      Entry.new(id: "self", area_key: "self", icon: "heart"),
      Entry.new(id: "career", area_key: "career", icon: "briefcase"),
      Entry.new(id: "money", area_key: "money", icon: "coin"),
      Entry.new(id: "relationships", area_key: "relationships", icon: "users"),
      Entry.new(id: "growth", area_key: "purpose", icon: "sprout"),
      Entry.new(id: "other", area_key: "purpose", icon: "dots")
    ].freeze

    IDS = ALL.map(&:id).freeze
    CATEGORY_FLAG = "onboarding_category"

    def self.all
      ALL
    end

    def self.find(id)
      ALL.find { |entry| entry.id == id.to_s }
    end

    def self.valid_id?(id)
      find(id).present?
    end

    def self.area_key_for(id)
      find(id)&.area_key
    end

    # Resolve which example set to show for a journey (chips / mountain copy).
    def self.id_for_journey(journey)
      flag = journey&.setup_flag(CATEGORY_FLAG).to_s
      return flag if valid_id?(flag)

      case journey&.life_area&.key.to_s
      when "self" then "self"
      when "career" then "career"
      when "money" then "money"
      when "relationships" then "relationships"
      when "purpose", "learning", "creativity" then "growth"
      else "other"
      end
    end

    # Shared chain for push copy + notification actions:
    # explicit category → focused journey → "other".
    def self.resolve_for(user:, explicit: nil)
      return explicit.to_s if valid_id?(explicit)

      journey = user.primary_focused_journey || user.focused_journeys.first
      id_for_journey(journey)
    end
  end
end
