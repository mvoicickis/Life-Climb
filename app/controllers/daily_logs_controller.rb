class DailyLogsController < ApplicationController
  before_action :set_habit

  def create
    @daily_log = current_user.daily_logs.find_or_initialize_by(habit: @habit, logged_on: Date.current)
    @daily_log.amount = daily_log_params[:amount].presence || 0
    @daily_log.goal = goal_for_log

    if @daily_log.save
      redirect_to habit_path(@habit, saved: 1, won: (won? ? 1 : 0)), notice: notice_for(@daily_log)
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

  def goal_for_log
    return @habit.goal if @habit.growth? && @habit.goal.present?
    return nil if @habit.standard?

    daily_log_params[:goal].presence || @habit.suggested_goal_for_today
  end

  def won?
    @habit.met_habit_goal? || (@daily_log.goal.present? && @daily_log.met_goal?)
  end

  def notice_for(log)
    habit = log.habit
    parts = [ "Saved #{format_num(log.amount)} #{habit.unit}." ]
    parts << "#{habit.status_label}."
    if habit.met_habit_goal?
      parts << "You hit your goal!"
    end
    parts.join(" ")
  end

  def format_num(amount)
    amount == amount.to_i ? amount.to_i : amount
  end
end
