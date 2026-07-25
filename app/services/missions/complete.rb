# frozen_string_literal: true

module Missions
  class Complete
    class Error < StandardError; end

    def self.call(user:, mission:)
      new(user:, mission:).call
    end

    def initialize(user:, mission:)
      @user = user
      @mission = mission
    end

    def call
      raise Error, "Mission not found" unless @mission
      raise Error, "Not your mission" unless @mission.user_id == @user.id
      return @mission if @mission.completed?

      ActiveRecord::Base.transaction do
        @mission.update!(completed_at: Time.current, status: "complete")
        LifePoints::Award.call(
          user: @user,
          amount: @mission.lp_reward,
          reason: I18n.t("missions.lp_reason", title: @mission.title),
          source: @mission
        )
        Gap::ApplyMissionDelta.call(journey: @mission.life_journey, mission: @mission)
        @mission
      end
    end
  end
end
