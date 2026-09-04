# frozen_string_literal: true

module Battles
  # Win one camp-sheet battle — same AP/streak path as BattleWinsController / Today checkbox.
  class WinFromMountain
    Result = Struct.new(:awarded, :battle, :flash, keyword_init: true)

    def self.call(battle:, user:, session:)
      new(battle: battle, user: user, session: session).call
    end

    def initialize(battle:, user:, session:)
      @battle = battle
      @user = user
      @session = session
    end

    def call
      battle = @battle
      journey = battle.life_journey || @user.primary_focused_journey
      amount = GameRules::BATTLE_TODO_LP
      flash_data = {}

      if battle.quantified_path_project.present?
        raise ArgumentError, I18n.t("strategy.rpg.trail.log_needed")
      end

      if battle.completed? && !battle.repeat_daily?
        return Result.new(awarded: 0, battle: battle.reload, flash: flash_data)
      end

      Strategy::CascadeToDaily.call(user: @user, life_area: battle.life_area) if battle.life_area
      todo = @user.daily_todos.for_day.find_by(strategy_goal_id: battle.id)

      if todo && !todo.completed?
        result = CompleteTodo.call(todo: todo, user: @user, session: @session)
        flash_data[:ap_gained] = result.awarded
        flash_data[:battle_celebrate] = true
        return Result.new(awarded: result.awarded, battle: battle.reload, flash: flash_data)
      end

      if battle.repeat_daily?
        next_day = [ Date.current + 1.day, (battle.scheduled_on || Date.current) + 1.day ].max
        battle.update!(scheduled_on: next_day, completed_at: nil)
        Strategy::CascadeToDaily.call(user: @user, life_area: battle.life_area) if battle.life_area
        return Result.new(awarded: 0, battle: battle.reload, flash: flash_data)
      end

      if battle.completed?
        return Result.new(awarded: 0, battle: battle.reload, flash: flash_data)
      end

      already_paid = WinAlreadyPaid.for_battle?(battle, todo: todo)
      awarded = already_paid ? 0 : amount

      ActiveRecord::Base.transaction do
        battle.complete!
        if todo && !todo.completed?
          todo.update!(completed_at: Time.current)
        end
        unless already_paid
          LifePoints::Award.call(
            user: @user,
            amount: amount,
            reason: I18n.t("battle.lp_reason", title: battle.title),
            source: battle
          )
        end
        Gap::ApplyProgress.call(journey: journey, tier: :todo) if journey
      end

      streak = Climb::Streak.touch!(user: @user)
      pb = Climb::PersonalBest.record!(user: @user, awarded: awarded)
      Strategy::ProjectCheckQueue.enqueue(
        session: @session,
        project_ids: Strategy::ProjectCheckQueue.from_battles([ battle ])
      )
      Journeys::SyncClimbFromToday.call(user: @user) if journey
      Today::OvershootBonus.sync!(user: @user)

      Analytics::TrackFirstBattleWon.call(user: @user)

      flash_data[:ap_gained] = awarded
      flash_data[:battle_celebrate] = true
      if awarded.positive? && (pb.new_record || streak.earned_freeze)
        flash_data[:climb_boss] = true
        goal = journey && @user.strategy_goals.for_area(journey.life_area_id).for_kind("goal").roots.first
        flash_data[:climb_reward] = Climb::Reward.for_battle(
          user: @user,
          awarded: awarded,
          goal: goal,
          streak_days: streak.days,
          personal_best: pb.new_record,
          earned_freeze: streak.earned_freeze,
          boss: true
        )
      end

      Result.new(awarded: awarded, battle: battle.reload, flash: flash_data)
    end
  end
end
