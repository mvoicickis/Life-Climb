# frozen_string_literal: true

# Mountain V4: log a quantity toward a quantified camp, optionally winning a battle.
class StrategyQuantityLogsController < ApplicationController
  def create
    project = current_user.strategy_goals.for_kind("project").find(params.require(:project_id))
    raise ActiveRecord::RecordNotFound unless project.quantified?

    amount = params.require(:amount)
    battle =
      if params[:battle_id].present?
        current_user.strategy_goals.battles.find(params[:battle_id])
      end

    if battle && battle.parent_id != project.id
      redirect_to dashboard_path, alert: t("dash.battle_angles.invalid"), status: :see_other and return
    end

    journey = project.life_journey ||
              current_user.life_journeys.active.find_by(id: params[:life_journey_id]) ||
              current_user.primary_focused_journey

    Strategy::Quantity::Log.call(
      project: project,
      amount: amount,
      user: current_user,
      source_day: battle
    )

    awarded = 0
    if battle && !battle.completed?
      todo = current_user.daily_todos.for_day.find_by(strategy_goal_id: battle.id)
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
      Strategy::ProjectCheckQueue.enqueue(
        session: session,
        project_ids: Strategy::ProjectCheckQueue.from_battles([ battle ])
      )
      Journeys::SyncClimbFromToday.call(user: current_user) if journey
      Today::OvershootBonus.sync!(user: current_user)
      flash[:ap_gained] = awarded
      flash[:battle_celebrate] = true
    end

    plan = project.parent
    goal = plan&.parent || project.root_goal
    redirect_to life_journey_path(
                  journey,
                  goal_id: goal&.id,
                  plan_id: plan&.id,
                  focus_id: project.id
                ),
                notice: I18n.t("strategy.quantity.logged", unit: project.unit),
                status: :see_other
  rescue ArgumentError => e
    redirect_back fallback_location: dashboard_path, alert: e.message, status: :see_other
  rescue ActiveRecord::RecordNotFound
    redirect_to dashboard_path, alert: t("dash.battle_angles.invalid"), status: :see_other
  end
end
