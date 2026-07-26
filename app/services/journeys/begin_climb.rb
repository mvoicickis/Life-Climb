# frozen_string_literal: true

module Journeys
  # Start a new climb after completion. Focus = this Journey only.
  class BeginClimb
    class Error < StandardError; end

    def self.call(user:, area_key:, ideal_scene:, current_reality:, next_win:, today_mission:, title: nil, closer_percent: 30)
      new(
        user:,
        area_key:,
        title:,
        ideal_scene:,
        current_reality:,
        next_win:,
        today_mission:,
        closer_percent:
      ).call
    end

    def initialize(user:, area_key:, title:, ideal_scene:, current_reality:, next_win:, today_mission:, closer_percent:)
      @user = user
      @area_key = area_key.to_s
      @title = title
      @ideal_scene = ideal_scene
      @current_reality = current_reality
      @next_win = next_win
      @today_mission = today_mission.to_s.strip
      @closer_percent = closer_percent
    end

    def call
      raise Error, "Pick a life area" unless LifeArea::CATALOG_KEYS.include?(@area_key)
      raise Error, "Say one thing you can finish in one sitting" if @today_mission.blank?

      ActiveRecord::Base.transaction do
        areas = LifeAreas::Select.call(user: @user, keys: [ @area_key ])
        area = areas.find { |a| a.key == @area_key }
        raise Error, "Could not open that life area" unless area

        journey = Journeys::Create.call(
          user: @user,
          life_area: area,
          title: @title,
          ideal_scene: @ideal_scene,
          current_reality: @current_reality,
          next_win: @next_win,
          closer_percent: @closer_percent
        )
        Focus::SetJourneys.call(user: @user, journey_ids: [ journey.id ])
        Missions::EnsureDaily.call(user: @user, mission_title: @today_mission)
        journey
      end
    end
  end
end
