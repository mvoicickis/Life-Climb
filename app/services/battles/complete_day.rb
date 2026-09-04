# frozen_string_literal: true

module Battles
  # DEPRECATED: Today completes one checkbox at a time via DailyTodosController /
  # MissionCompletionsController. Kept for now so existing tests and the unused
  # battle_completions route still resolve — do not wire new UI to this.
  #
  # Completes remaining open battle items for today and awards LP once per item.
  # Linked Strategy battles are marked complete.
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
        return Result.new(
          ok: false,
          awarded: 0,
          message: I18n.t("dash.battle.empty_cta")
        )
      end

      awarded = 0
      journey = @user.primary_focused_journey

      ApplicationRecord.transaction do
        todos.each do |todo|
          todo.update!(completed_at: Time.current)
          if todo.strategy_goal
            todo.strategy_goal.complete!
          end
          unless WinAlreadyPaid.for_todo?(todo)
            LifePoints::Award.call(
              user: @user,
              amount: todo.lp_reward,
              reason: I18n.t("battle.lp_reason", title: todo.title),
              source: todo
            )
            awarded += todo.lp_reward.to_i
          end
          Gap::ApplyProgress.call(journey: journey, tier: :todo)
        end

        if include_mission
          Missions::Complete.call(user: @user, mission: mission)
          awarded += mission.lp_reward.to_i
        end
      end

      Today::OvershootBonus.sync!(user: @user)

      Result.new(
        ok: true,
        awarded: awarded,
        message: I18n.t("dash.battle.complete_success", lp: awarded)
      )
    end

    private

    def primary_open_mission
      journey = @user.primary_focused_journey
      return unless journey

      journey.missions.for_day.primary.incomplete.order(:id).first
    end
  end
end
