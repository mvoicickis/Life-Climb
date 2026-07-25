# frozen_string_literal: true

module Journeys
  # Start a new climb (after completion or from Life Map). Keeps prior Areas; Focus = this Journey only.
  class BeginClimb
    class Error < StandardError; end

    def self.call(user:, area_key:, title:, ideal_scene:, current_reality:, closer_percent: 30)
      new(
        user:,
        area_key:,
        title:,
        ideal_scene:,
        current_reality:,
        closer_percent:
      ).call
    end

    def initialize(user:, area_key:, title:, ideal_scene:, current_reality:, closer_percent:)
      @user = user
      @area_key = area_key.to_s
      @title = title
      @ideal_scene = ideal_scene
      @current_reality = current_reality
      @closer_percent = closer_percent
    end

    def call
      raise Error, "Pick a life area" unless LifeArea::CATALOG_KEYS.include?(@area_key)

      ActiveRecord::Base.transaction do
        keys = (@user.life_areas.v2_selected.pluck(:key) + [ @area_key ]).uniq
        areas = LifeAreas::Select.call(user: @user, keys: keys)
        area = areas.find { |a| a.key == @area_key }
        raise Error, "Could not open that life area" unless area

        journey = Journeys::Create.call(
          user: @user,
          life_area: area,
          title: @title,
          ideal_scene: @ideal_scene,
          current_reality: @current_reality,
          closer_percent: @closer_percent
        )
        Focus::SetJourneys.call(user: @user, journey_ids: [ journey.id ])
        Missions::EnsureDaily.call(user: @user)
        journey
      end
    end
  end
end
