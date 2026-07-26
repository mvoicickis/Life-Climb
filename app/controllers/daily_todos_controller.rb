# frozen_string_literal: true

class DailyTodosController < ApplicationController
  def create
    todo = current_user.daily_todos.new(todo_params)
    todo.scheduled_on = Date.current
    todo.position = current_user.daily_todos.for_day.count
    todo.lp_reward ||= GameRules::BATTLE_TODO_LP
    if todo.save
      Journeys::SyncClimbFromToday.call(user: current_user)
      redirect_to dashboard_path, notice: t("battle_plan.added")
    else
      redirect_to dashboard_path, alert: todo.errors.full_messages.to_sentence.presence || t("dash.battle_day_full", max: GameRules::MAX_DAILY_TODOS)
    end
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

  private

  def todo_params
    params.require(:daily_todo).permit(:title, :aspect_key, :lp_reward, :tag)
  end
end
