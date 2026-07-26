# frozen_string_literal: true

module Battles
  # Completes remaining open battle items for today and awards LP once per item.
  # Linked Strategy battles are marked complete so the mountain progress rolls up.
  class CompleteDay
    Result = Struct.new(:ok, :awarded, :message, :progress_before, :progress_after, keyword_init: true)

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
        return Result.new(
          ok: false,
          awarded: 0,
          message: I18n.t("dash.battle.empty_cta"),
          progress_before: current_progress,
          progress_after: current_progress
        )
      end

      awarded = 0
      journey = @user.primary_focused_journey
      progress_before = current_progress

      ApplicationRecord.transaction do
        todos.each do |todo|
          todo.update!(completed_at: Time.current)
          todo.strategy_goal&.complete!
          LifePoints::Award.call(
            user: @user,
            amount: todo.lp_reward,
            reason: I18n.t("battle.lp_reason", title: todo.title),
            source: todo
          )
          Gap::ApplyProgress.call(journey: journey, tier: :todo)
          awarded += todo.lp_reward.to_i
        end

        if include_mission
          Missions::Complete.call(user: @user, mission: mission)
          awarded += mission.lp_reward.to_i
        end
      end

      progress_after = current_progress
      Result.new(
        ok: true,
        awarded: awarded,
        progress_before: progress_before,
        progress_after: progress_after,
        message: success_message(awarded: awarded, before: progress_before, after: progress_after)
      )
    end

    private

    def primary_open_mission
      journey = @user.primary_focused_journey
      return unless journey

      journey.missions.for_day.primary.incomplete.order(:id).first
    end

    def current_progress
      journey = @user.primary_focused_journey
      return 0 unless journey

      goal = @user.strategy_goals.for_area(journey.life_area_id).for_kind("goal").roots.first
      return goal.progress_percent.to_i if goal

      journey.closer_percent.round
    end

    def success_message(awarded:, before:, after:)
      if after > before
        I18n.t("dash.battle.complete_success_climb", lp: awarded, percent: after)
      else
        I18n.t("dash.battle.complete_success", lp: awarded)
      end
    end
  end
end
