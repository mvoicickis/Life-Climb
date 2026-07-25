# frozen_string_literal: true

module Onboarding
  # Thin v2 path: areas → journey → focus → mission → home.
  class Run
    class Error < StandardError; end

    def self.call(user:, area_keys:, title:, ideal_scene:, current_reality:, closer_percent: 30)
      new(
        user:,
        area_keys:,
        title:,
        ideal_scene:,
        current_reality:,
        closer_percent:
      ).call
    end

    def initialize(user:, area_keys:, title:, ideal_scene:, current_reality:, closer_percent:)
      @user = user
      @area_keys = area_keys
      @title = title
      @ideal_scene = ideal_scene
      @current_reality = current_reality
      @closer_percent = closer_percent
    end

    def call
      ActiveRecord::Base.transaction do
        areas = LifeAreas::Select.call(user: @user, keys: @area_keys)
        primary_area = areas.first
        journey = Journeys::Create.call(
          user: @user,
          life_area: primary_area,
          title: @title,
          ideal_scene: @ideal_scene,
          current_reality: @current_reality,
          closer_percent: @closer_percent
        )
        Focus::SetJourneys.call(user: @user, journey_ids: [ journey.id ])
        Missions::EnsureDaily.call(user: @user)
        @user.update!(onboarding_completed_at: Time.current, planning_version: 2)
        journey
      end
    end
  end
end
