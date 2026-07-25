# frozen_string_literal: true

class DailyTodosController < ApplicationController
  def create
    todo = current_user.daily_todos.new(todo_params)
    todo.scheduled_on = Date.current
    todo.position = current_user.daily_todos.for_day.count
    todo.lp_reward ||= GameRules::BATTLE_TODO_LP
    if todo.save
      redirect_to dashboard_path, notice: t("battle_plan.added")
    else
      redirect_to dashboard_path, alert: todo.errors.full_messages.to_sentence
    end
  end

  def complete
    todo = current_user.daily_todos.find(params[:id])
    if todo.completed?
      todo.update!(completed_at: nil)
    else
      ActiveRecord::Base.transaction do
        todo.update!(completed_at: Time.current)
        LifePoints::Award.call(
          user: current_user,
          amount: todo.lp_reward,
          reason: I18n.t("battle.lp_reason", title: todo.title),
          source: todo
        )
        GameRules.apply_todo_gap!(current_user.primary_focused_journey)
      end
    end
    redirect_to dashboard_path
  end

  def destroy
    todo = current_user.daily_todos.find(params[:id])
    todo.destroy!
    redirect_to dashboard_path
  end

  private

  def todo_params
    params.require(:daily_todo).permit(:title, :aspect_key, :lp_reward)
  end
end
