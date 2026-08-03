# frozen_string_literal: true

class DailyTodosController < ApplicationController
  # Freeform battles are planned on Strategy and synced to Today.
  # Today only completes / undoes / removes already-fed battles.
  def create
    journey = current_user.primary_focused_journey
    redirect_to(
      (journey ? life_journey_path(journey) : dashboard_path),
      alert: t("dash.battle_plan_on_strategy")
    )
  end

  def complete
    todo = current_user.daily_todos.find(params[:id])
    if todo.completed?
      ActiveRecord::Base.transaction do
        Strategy::Quantity::Unlog.call(daily_todo: todo)
        todo.update!(completed_at: nil)
        # Daily templates stay open; only one-time goals need reopen.
        todo.strategy_goal&.reopen! unless todo.strategy_goal&.repeat_daily?
      end
    else
      project = todo.strategy_goal&.quantified_path_project
      if project && !valid_quantity_amount?(params[:amount])
        redirect_to dashboard_path,
                    alert: t("strategy.quantity.amount_required", unit: project.unit)
        return
      end

      ActiveRecord::Base.transaction do
        if project
          Strategy::Quantity::Log.call(
            project: project,
            amount: params[:amount],
            user: current_user,
            source_day: todo.strategy_goal,
            daily_todo: todo
          )
        end
        todo.update!(completed_at: Time.current)
        finish_linked_strategy_goal!(todo)
        LifePoints::Award.call(
          user: current_user,
          amount: todo.lp_reward,
          reason: I18n.t("battle.lp_reason", title: todo.title),
          source: todo
        )
        Gap::ApplyProgress.call(journey: current_user.primary_focused_journey, tier: :todo)
      end
      streak = Climb::Streak.touch!(user: current_user)
      pb = Climb::PersonalBest.record!(user: current_user, awarded: todo.lp_reward.to_i)
      Strategy::ProjectCheckQueue.enqueue(
        session: session,
        project_ids: Strategy::ProjectCheckQueue.from_battles([ todo.strategy_goal ].compact)
      )
      # Light juice on every checkbox — full Climb Reward modal only for milestones.
      flash[:ap_gained] = todo.lp_reward.to_i
      flash[:battle_celebrate] = true
      maybe_milestone_climb_reward!(
        awarded: todo.lp_reward.to_i,
        streak: streak,
        personal_best: pb.new_record
      )
    end
    Journeys::SyncClimbFromToday.call(user: current_user)
    redirect_to dashboard_path
  end

  def destroy
    todo = current_user.daily_todos.find(params[:id])
    todo.destroy!
    Journeys::SyncClimbFromToday.call(user: current_user)
    redirect_to dashboard_path
  end

  private

  def valid_quantity_amount?(raw)
    return false if raw.blank?

    BigDecimal(raw.to_s).positive?
  rescue ArgumentError
    false
  end

  # One-time battles finish the day goal. Daily templates roll to the next day.
  def finish_linked_strategy_goal!(todo)
    goal = todo.strategy_goal
    return if goal.blank?

    unless goal.repeat_daily?
      goal.complete!
      return
    end

    next_day = [ Date.current + 1.day, todo.scheduled_on + 1.day ].max
    goal.update!(scheduled_on: next_day, completed_at: nil)
    Strategy::CascadeToDaily.call(user: current_user, life_area: goal.life_area)
  end

  def maybe_milestone_climb_reward!(awarded:, streak:, personal_best:)
    milestone = personal_best || streak.earned_freeze
    return unless milestone

    flash[:climb_boss] = true
    journey = current_user.primary_focused_journey
    goal = journey && current_user.strategy_goals.for_area(journey.life_area_id).for_kind("goal").roots.first
    flash[:climb_reward] = Climb::Reward.for_battle(
      user: current_user,
      awarded: awarded,
      goal: goal,
      streak_days: streak.days,
      personal_best: personal_best,
      earned_freeze: streak.earned_freeze,
      boss: true
    )
  end
end
