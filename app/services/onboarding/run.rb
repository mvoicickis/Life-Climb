# frozen_string_literal: true

module Onboarding
  # MVP start: pick a mountain → forge journey + strategy goal + Plan Your Route mission.
  class Run
    class Error < StandardError; end

    DEFAULT_AREA_KEY = "self".freeze
    ROUTE_FLAG = "route".freeze

    def self.call(user:, title: nil, area_key: DEFAULT_AREA_KEY, ideal_scene: nil, current_reality: nil,
                  next_win: nil, today_mission: nil, closer_percent: 5, route_mission: false)
      new(
        user:,
        area_key:,
        title:,
        ideal_scene:,
        current_reality:,
        next_win:,
        today_mission:,
        closer_percent:,
        route_mission:
      ).call
    end

    def initialize(user:, area_key:, title:, ideal_scene:, current_reality:, next_win:, today_mission:, closer_percent:, route_mission:)
      @user = user
      @area_key = area_key.to_s.presence || DEFAULT_AREA_KEY
      @title = title.to_s.strip
      @ideal_scene = ideal_scene.to_s.strip
      @current_reality = current_reality.to_s.strip
      @next_win = next_win
      @today_mission = today_mission.to_s.strip
      @closer_percent = closer_percent
      @route_mission = route_mission
    end

    def call
      raise Error, "Pick one life area" unless LifeArea::CATALOG_KEYS.include?(@area_key)
      raise Error, I18n.t("v2_onboarding.need_mountain") if @title.blank? && @ideal_scene.blank?

      title = @title.presence || @ideal_scene.truncate(80)
      ideal = @ideal_scene.presence || I18n.t("v2_onboarding.default_ideal", title: title)
      reality = @current_reality.presence || I18n.t("v2_onboarding.default_reality")
      mission_title =
        if @route_mission
          I18n.t("v2_onboarding.route_mission_title")
        else
          @today_mission
        end
      raise Error, "Say one thing you can finish in one sitting" if mission_title.blank?

      ActiveRecord::Base.transaction do
        areas = LifeAreas::Select.call(user: @user, keys: [ @area_key ])
        primary_area = areas.find { |a| a.key == @area_key } || areas.first

        journey = Journeys::Create.call(
          user: @user,
          life_area: primary_area,
          title: title,
          ideal_scene: ideal,
          current_reality: reality,
          next_win: @next_win,
          closer_percent: @closer_percent
        )
        Focus::SetJourneys.call(user: @user, journey_ids: [ journey.id ])

        if @route_mission
          flags = (journey.setup_flags.presence || {}).stringify_keys.merge(ROUTE_FLAG => "pending")
          journey.update_columns(setup_flags: flags, updated_at: Time.current)
          journey.setup_flags = flags
        end

        mission = Missions::EnsureDaily.call(user: @user, mission_title: mission_title).first
        if @route_mission && mission
          mission.update!(lp_reward: GameRules::ROUTE_MISSION_LP)
        end

        if @route_mission
          goal = @user.strategy_goals.create!(
            life_area: primary_area,
            life_journey: journey,
            horizon: "goal",
            title: title,
            position: 0
          )
          Strategy::Celebrate.call(user: @user, goal: goal)
        end

        @user.update!(onboarding_completed_at: Time.current, planning_version: 2)
        journey
      end
    end
  end
end
