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
        todo.update!(completed_at: nil)
        todo.strategy_goal&.reopen!
      end
    else
      ActiveRecord::Base.transaction do
        todo.update!(completed_at: Time.current)
        todo.strategy_goal&.complete!
        LifePoints::Award.call(
          user: current_user,
          amount: todo.lp_reward,
          reason: I18n.t("battle.lp_reason", title: todo.title),
          source: todo
        )
        Gap::ApplyProgress.call(journey: current_user.primary_focused_journey, tier: :todo)
      end
      Strategy::ProjectCheckQueue.enqueue(
        session: session,
        project_ids: Strategy::ProjectCheckQueue.from_battles([ todo.strategy_goal ].compact)
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
end
