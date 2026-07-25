# frozen_string_literal: true

class DailyTodosController < ApplicationController
  def create
    todo = current_user.daily_todos.new(todo_params)
    todo.scheduled_on = Date.current
    todo.position = current_user.daily_todos.for_day.count
    if todo.save
      redirect_to dashboard_path(aspect: todo.aspect_key), notice: t("battle_plan.added")
    else
      redirect_to dashboard_path(aspect: params.dig(:daily_todo, :aspect_key)), alert: todo.errors.full_messages.to_sentence
    end
  end

  def complete
    todo = current_user.daily_todos.find(params[:id])
    if todo.completed?
      todo.update!(completed_at: nil)
    else
      todo.update!(completed_at: Time.current)
    end
    redirect_to dashboard_path(aspect: todo.aspect_key)
  end

  def destroy
    todo = current_user.daily_todos.find(params[:id])
    aspect = todo.aspect_key
    todo.destroy!
    redirect_to dashboard_path(aspect: aspect)
  end

  private

  def todo_params
    params.require(:daily_todo).permit(:title, :aspect_key)
  end
end
