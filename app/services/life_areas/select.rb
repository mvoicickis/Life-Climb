# frozen_string_literal: true

module LifeAreas
  # Upserts the user's selected Life Areas from the v2 catalog.
  # Soft UX default is 1–3 areas; the data model allows any non-empty subset.
  class Select
    class Error < StandardError; end

    def self.call(user:, keys:)
      new(user:, keys:).call
    end

    def initialize(user:, keys:)
      @user = user
      @keys = Array(keys).map(&:to_s)
    end

    def call
      raise Error, "user required" unless @user
      raise Error, "select at least one life area" if wanted.empty?
      unknown = @keys - LifeArea::CATALOG_KEYS
      raise Error, "unknown life area keys: #{unknown.join(', ')}" if unknown.any?

      ActiveRecord::Base.transaction do
        @user.update!(planning_version: 2) unless @user.planning_v2?

        existing = @user.life_areas.v2_selected.index_by(&:key)

        wanted.each_with_index do |key, index|
          area = existing.delete(key)
          attrs = {
            number: LifeArea.catalog_number(key),
            position: index,
            selected_at: Time.current,
            dream_id: nil,
            closer_score: area&.closer_score || 1
          }

          if area
            area.update!(attrs)
          else
            @user.life_areas.create!(attrs.merge(key: key, meta: {}))
          end
        end

        # Deselect removes v2 rows only; never touches dream-backed legacy areas.
        existing.each_value(&:destroy!)
      end

      @user.life_areas.v2_selected.ordered.reload
    end

    private

    def wanted
      @wanted ||= @keys.select { |key| LifeArea::CATALOG_KEYS.include?(key) }.uniq
    end
  end
end
