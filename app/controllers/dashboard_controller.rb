class DashboardController < ApplicationController
  def show
    @habits = current_user.habits.active.order(:name)
    @recent_completions = current_user.completions.includes(:habit).order(completed_on: :desc, created_at: :desc).limit(10)
  end
end
