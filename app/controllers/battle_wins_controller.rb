# frozen_string_literal: true

# Win one Strategy battle from the Mountain world map, then return to the climb.
class BattleWinsController < ApplicationController
  def create
    battle = current_user.strategy_goals.battles.find(params[:id])
    journey = battle.life_journey || current_user.primary_focused_journey
    amount = GameRules::BATTLE_TODO_LP

    if battle.completed?
      redirect_to mountain_return_path(journey, battle), status: :see_other and return
    end

    ActiveRecord::Base.transaction do
      battle.complete!
      todo = current_user.daily_todos.for_day.find_by(strategy_goal_id: battle.id)
      if todo && !todo.completed?
        todo.update!(completed_at: Time.current)
      end
      LifePoints::Award.call(
        user: current_user,
        amount: amount,
        reason: I18n.t("battle.lp_reason", title: battle.title),
        source: battle
      )
      Gap::ApplyProgress.call(journey: journey, tier: :todo) if journey
    end

    streak = Climb::Streak.touch!(user: current_user)
    pb = Climb::PersonalBest.record!(user: current_user, awarded: amount)
    Strategy::ProjectCheckQueue.enqueue(
      session: session,
      project_ids: Strategy::ProjectCheckQueue.from_battles([ battle ])
    )
    Journeys::SyncClimbFromToday.call(user: current_user) if journey

    flash[:ap_gained] = amount
    flash[:battle_celebrate] = true
    # Ordinary Mountain battle wins stay light; Climb Reward is for milestones only.
    if pb.new_record || streak.earned_freeze
      flash[:climb_boss] = true
      goal = journey && current_user.strategy_goals.for_area(journey.life_area_id).for_kind("goal").roots.first
      flash[:climb_reward] = Climb::Reward.for_battle(
        user: current_user,
        awarded: amount,
        goal: goal,
        streak_days: streak.days,
        personal_best: pb.new_record,
        earned_freeze: streak.earned_freeze,
        boss: true
      )
    end

    redirect_to mountain_return_path(journey, battle),
                notice: I18n.t("battle.completed_notice", lp: amount),
                status: :see_other
  rescue ActiveRecord::RecordNotFound
    redirect_to dashboard_path, alert: t("dash.battle_angles.invalid"), status: :see_other
  end

  private

  def mountain_return_path(journey, battle)
    project = battle.parent
    plan = project&.parent
    goal = plan&.parent || project&.root_goal
    life_journey_path(
      journey,
      goal_id: goal&.id,
      plan_id: plan&.id,
      focus_id: project&.id
    )
  end
end
