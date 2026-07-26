# frozen_string_literal: true

module LifeAreas
  # Upserts the user's single selected Life Area from the v2 catalog (one mountain).
  class Select
    class Error < StandardError; end

    def self.call(user:, keys:)
      new(user:, keys:).call
    end

    def initialize(user:, keys:)
      @user = user
      @keys = Array(keys).map(&:to_s).compact_blank
    end

    def call
      raise Error, "user required" unless @user
      raise Error, I18n.t("life_area_selections.need_one") if wanted.empty?
      raise Error, I18n.t("life_area_selections.only_one") if wanted.size > 1
      unknown = @keys - LifeArea::CATALOG_KEYS
      raise Error, "unknown life area keys: #{unknown.join(', ')}" if unknown.any?

      key = wanted.first

      ActiveRecord::Base.transaction do
        @user.update!(planning_version: 2) unless @user.planning_v2?

        existing = @user.life_areas.where(dream_id: nil).index_by(&:key)

        # Deselect previous v2 areas without destroying journeys (restrict_with_error).
        existing.each do |area_key, area|
          next if area_key == key
          next if area.selected_at.nil?

          area.update!(selected_at: nil)
        end

        area = existing[key]
        attrs = {
          number: LifeArea.catalog_number(key),
          position: 0,
          selected_at: Time.current,
          dream_id: nil,
          closer_score: area&.closer_score || 1
        }

        if area
          area.update!(attrs)
        else
          area = @user.life_areas.create!(attrs.merge(key: key, meta: {}))
        end

        # One mountain: drop focus on journeys outside the selected area.
        @user.life_journeys.where.not(life_area_id: area.id).where.not(focus_position: nil).find_each do |journey|
          journey.update!(focus_position: nil)
        end
      end

      @user.life_areas.v2_selected.ordered.reload
    end

    private

    def wanted
      @wanted ||= @keys.select { |key| LifeArea::CATALOG_KEYS.include?(key) }.uniq
    end
  end
end
