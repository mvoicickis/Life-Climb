class DailyLogsController < ApplicationController
  before_action :set_habit

  def create
    @daily_log = current_user.daily_logs.find_or_initialize_by(habit: @habit, logged_on: Date.current)
    @daily_log.amount = daily_log_params[:amount].presence || 0
    @daily_log.goal = daily_log_params[:goal].presence || @habit.suggested_goal_for_today

    if @daily_log.save
      redirect_to habit_path(@habit, saved: 1, won: (@daily_log.met_goal? ? 1 : 0)), notice: notice_for(@daily_log)
    else
      redirect_to habit_path(@habit), alert: @daily_log.errors.full_messages.to_sentence
    end
  end

  private

  def set_habit
    @habit = current_user.habits.find(params[:habit_id])
  end

  def daily_log_params
    params.require(:daily_log).permit(:amount, :goal)
  end

  def notice_for(log)
    habit = log.habit
    parts = [ "Saved #{format_num(log.amount)} #{habit.unit}." ]
    parts << "#{habit.vs_yesterday_label}."
    parts << (log.met_goal? ? "You hit your goal!" : "Keep going.") if log.goal.present?
    parts.join(" ")
  end

  def format_num(amount)
    amount == amount.to_i ? amount.to_i : amount
  end
end
