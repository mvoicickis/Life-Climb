# frozen_string_literal: true

module Battles
  # Completes remaining open battle items for today and awards LP once per item.
  class CompleteDay
    Result = Struct.new(:ok, :awarded, :message, keyword_init: true)

    def self.call(user:)
      new(user: user).call
    end

    def initialize(user:)
      @user = user
    end

    def call
      todos = @user.daily_todos.for_day.incomplete.ordered.to_a
      mission = primary_open_mission
      include_mission = mission.present?

      if todos.empty? && !include_mission
        return Result.new(ok: false, awarded: 0, message: I18n.t("dash.battle.empty_cta"))
      end

      awarded = 0
      journey = @user.primary_focused_journey

      ApplicationRecord.transaction do
        todos.each do |todo|
          todo.update!(completed_at: Time.current)
          LifePoints::Award.call(
            user: @user,
            amount: todo.lp_reward,
            reason: I18n.t("battle.lp_reason", title: todo.title),
            source: todo
          )
          GameRules.apply_todo_gap!(journey)
          awarded += todo.lp_reward.to_i
        end

        if include_mission
          Missions::Complete.call(user: @user, mission: mission)
          awarded += mission.lp_reward.to_i
        end
      end

      Result.new(ok: true, awarded: awarded, message: I18n.t("dash.battle.complete_success", lp: awarded))
    end

    private

    def primary_open_mission
      journey = @user.primary_focused_journey
      return unless journey

      journey.missions.for_day.primary.incomplete.order(:id).first
    end
  end
end
