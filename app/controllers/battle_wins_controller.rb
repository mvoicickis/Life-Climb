# frozen_string_literal: true

# Win one Strategy battle from the Mountain world map, then return to the climb.
class BattleWinsController < ApplicationController
  def create
    battle = current_user.strategy_goals.battles.find(params[:id])
    journey = battle.life_journey || current_user.primary_focused_journey
    amount = GameRules::BATTLE_TODO_LP

    if battle.quantified_path_project.present?
      redirect_to mountain_return_path(journey, battle),
                  alert: t("strategy.rpg.trail.log_needed"),
                  status: :see_other and return
    end

    if battle.completed? && !battle.repeat_daily?
      respond_to_quick_win(journey, battle, awarded: 0) and return
    end

    Strategy::CascadeToDaily.call(user: current_user, life_area: battle.life_area) if battle.life_area
    todo = current_user.daily_todos.for_day.find_by(strategy_goal_id: battle.id)

    if todo && !todo.completed?
      result = Battles::CompleteTodo.call(todo: todo, user: current_user, session: session)
      flash[:ap_gained] = result.awarded
      flash[:battle_celebrate] = true
      respond_to_quick_win(journey, battle, awarded: result.awarded) and return
    end

    if battle.repeat_daily?
      next_day = [ Date.current + 1.day, (battle.scheduled_on || Date.current) + 1.day ].max
      battle.update!(scheduled_on: next_day, completed_at: nil)
      Strategy::CascadeToDaily.call(user: current_user, life_area: battle.life_area) if battle.life_area
      respond_to_quick_win(journey, battle, awarded: 0) and return
    end

    if battle.completed?
      respond_to_quick_win(journey, battle, awarded: 0) and return
    end

    already_paid = Battles::WinAlreadyPaid.for_battle?(battle, todo: todo)
    awarded = already_paid ? 0 : amount

    ActiveRecord::Base.transaction do
      battle.complete!
      if todo && !todo.completed?
        todo.update!(completed_at: Time.current)
      end
      unless already_paid
        LifePoints::Award.call(
          user: current_user,
          amount: amount,
          reason: I18n.t("battle.lp_reason", title: battle.title),
          source: battle
        )
      end
      Gap::ApplyProgress.call(journey: journey, tier: :todo) if journey
    end

    streak = Climb::Streak.touch!(user: current_user)
    pb = Climb::PersonalBest.record!(user: current_user, awarded: awarded)
    Strategy::ProjectCheckQueue.enqueue(
      session: session,
      project_ids: Strategy::ProjectCheckQueue.from_battles([ battle ])
    )
    Journeys::SyncClimbFromToday.call(user: current_user) if journey
    Today::OvershootBonus.sync!(user: current_user)

    flash[:ap_gained] = awarded
    flash[:battle_celebrate] = true
    if awarded.positive? && (pb.new_record || streak.earned_freeze)
      flash[:climb_boss] = true
      goal = journey && current_user.strategy_goals.for_area(journey.life_area_id).for_kind("goal").roots.first
      flash[:climb_reward] = Climb::Reward.for_battle(
        user: current_user,
        awarded: awarded,
        goal: goal,
        streak_days: streak.days,
        personal_best: pb.new_record,
        earned_freeze: streak.earned_freeze,
        boss: true
      )
    end

    respond_to_quick_win(journey, battle, awarded: awarded)
  rescue ActiveRecord::RecordNotFound
    redirect_to dashboard_path, alert: t("dash.battle_angles.invalid"), status: :see_other
  end

  private

  def respond_to_quick_win(journey, battle, awarded:)
    respond_to do |format|
      format.turbo_stream do
        @journey = journey
        @battle = battle
        @awarded = awarded
        render :create, status: :ok
      end
      format.html do
        redirect_to mountain_return_path(journey, battle),
                    notice: I18n.t("battle.completed_notice", lp: awarded),
                    status: :see_other
      end
      format.any do
        redirect_to mountain_return_path(journey, battle), status: :see_other
      end
    end
  end

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
