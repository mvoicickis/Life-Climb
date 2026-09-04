# frozen_string_literal: true

# Mountain V4: log a quantity toward a quantified camp or day, optionally winning a battle.
class StrategyQuantityLogsController < ApplicationController
  include MountainSheetRefresh
  def create
    project = current_user.strategy_goals.find(params.require(:project_id))
    raise ActiveRecord::RecordNotFound unless project.quantified?

    amount = params.require(:amount)
    battle =
      if params[:battle_id].present?
        current_user.strategy_goals.battles.find(params[:battle_id])
      elsif project.day?
        project
      end

    unless battle_matches_project?(battle, project)
      redirect_to dashboard_path, alert: t("dash.battle_angles.invalid"), status: :see_other and return
    end

    journey = project.life_journey || battle&.life_journey ||
              current_user.life_journeys.active.find_by(id: params[:life_journey_id]) ||
              current_user.primary_focused_journey

    Strategy::Quantity::Log.call(
      project: project,
      amount: amount,
      user: current_user,
      source_day: battle
    )

    awarded = finish_logged_battle!(battle, journey)
    @awarded = awarded
    assign_mountain_sheet_for!(battle.presence || project)

    camp = @project
    plan = @plan
    goal = @goal
    respond_to do |format|
      format.turbo_stream { render :create, status: :ok }
      format.html do
        redirect_to life_journey_path(
                      journey,
                      goal_id: goal&.id,
                      plan_id: plan&.id,
                      focus_id: camp&.id
                    ),
                    notice: I18n.t("strategy.quantity.logged", unit: project.unit),
                    status: :see_other
      end
    end
  rescue ArgumentError => e
    redirect_back fallback_location: dashboard_path, alert: e.message, status: :see_other
  rescue ActiveRecord::RecordNotFound
    redirect_to dashboard_path, alert: t("dash.battle_angles.invalid"), status: :see_other
  end

  private

  def battle_matches_project?(battle, project)
    return true if battle.blank?
    return true if battle.id == project.id
    return true if battle.parent_id == project.id
    return true if battle.quantified_path_project&.id == project.id

    false
  end

  def finish_logged_battle!(battle, journey)
    return 0 if battle.blank?
    return 0 if battle.completed? && !battle.repeat_daily?

    Strategy::CascadeToDaily.call(user: current_user, life_area: battle.life_area) if battle.life_area
    todo = current_user.daily_todos.for_day.find_by(strategy_goal_id: battle.id)
    if todo && !todo.completed?
      result = Battles::CompleteTodo.call(
        todo: todo,
        user: current_user,
        session: session,
        already_logged: true
      )
      flash[:ap_gained] = result.awarded
      flash[:battle_celebrate] = true
      return result.awarded
    end

    if battle.repeat_daily?
      next_day = [ Date.current + 1.day, (battle.scheduled_on || Date.current) + 1.day ].max
      battle.update!(scheduled_on: next_day, completed_at: nil)
      Strategy::CascadeToDaily.call(user: current_user, life_area: battle.life_area) if battle.life_area
      return 0
    end

    return 0 if battle.completed?

    already_paid = Battles::WinAlreadyPaid.for_battle?(battle, todo: todo)
    amount_lp = GameRules::BATTLE_TODO_LP
    awarded = already_paid ? 0 : amount_lp

    ActiveRecord::Base.transaction do
      battle.complete!
      if todo && !todo.completed?
        todo.update!(completed_at: Time.current)
      end
      unless already_paid
        LifePoints::Award.call(
          user: current_user,
          amount: amount_lp,
          reason: I18n.t("battle.lp_reason", title: battle.title),
          source: battle
        )
      end
      Gap::ApplyProgress.call(journey: journey, tier: :todo) if journey
    end

    Climb::Streak.touch!(user: current_user)
    Journeys::SyncClimbFromToday.call(user: current_user) if journey
    Today::OvershootBonus.sync!(user: current_user)
    flash[:ap_gained] = awarded
    flash[:battle_celebrate] = true
    awarded
  end
end
