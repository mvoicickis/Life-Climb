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
      Battles::UncompleteTodo.call(todo: todo, user: current_user)
    else
      day = todo.strategy_goal
      if day&.practice_tasks&.incomplete&.exists?
        redirect_to dashboard_path, alert: t("dash.checklist_finish_objectives")
        return
      end

      checklist = day&.practice_tasks&.any?
      project = checklist ? nil : day&.quantified_path_project
      if project && !valid_quantity_amount?(params[:amount])
        redirect_to dashboard_path,
                    alert: t("strategy.quantity.amount_required", unit: project.unit)
        return
      end

      begin
        result = Battles::CompleteTodo.call(
          todo: todo,
          user: current_user,
          session: session,
          amount: params[:amount]
        )
      rescue ArgumentError
        redirect_to dashboard_path, alert: t("dash.checklist_finish_objectives")
        return
      end

      flash[:ap_gained] = todo.lp_reward.to_i
      flash[:battle_celebrate] = true
      maybe_milestone_climb_reward!(
        awarded: todo.lp_reward.to_i,
        streak: result.streak,
        personal_best: result.personal_best_new
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
