class HabitsController < ApplicationController
  before_action :set_habit, only: %i[ show edit update destroy raise_goal decline_goal_raise ]

  def index
    @habits = current_user.habits.ordered
  end

  def show
    insights = DashboardInsights.new(current_user, trackers: [ @habit ])
    @streak = insights.streak_days
    @share_worthy = insights.personal_record?(@habit) || insights.big_boost?(@habit) || DashboardInsights::STREAK_MILESTONES.include?(@streak)
    @milestone_label =
      if insights.personal_record?(@habit)
        I18n.t("habits.milestone_record")
      elsif DashboardInsights::STREAK_MILESTONES.include?(@streak)
        I18n.t("habits.milestone_streak", count: @streak)
      elsif insights.big_boost?(@habit)
        I18n.t("habits.milestone_boost")
      end
  end

  def new
    @habit = current_user.habits.build(
      points: 5,
      frequency: "daily",
      active: true,
      unit: "times",
      show_on_home: true,
      stat_type: "growth"
    )
  end

  def create
    @habit = current_user.habits.build(habit_params)
    @habit.show_on_home = true if @habit.show_on_home.nil?
    @habit.active = true if @habit.active.nil?
    @habit.stat_type = "growth" if @habit.stat_type.blank?
    clear_targets_unless_configured!

    if @habit.save
      redirect_to dashboard_path, notice: "Added. Start logging today — small steps count."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    @habit.assign_attributes(habit_params)
    clear_targets_unless_configured!

    if @habit.save
      redirect_to habits_path, notice: "Saved."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @habit.destroy
    redirect_to habits_path, notice: "Removed.", status: :see_other
  end

  def raise_goal
    if @habit.raise_goal!
      redirect_to habit_path(@habit), notice: "Goal raised. Keep going."
    else
      redirect_to habit_path(@habit), alert: "Set a goal first."
    end
  end

  def decline_goal_raise
    @habit.decline_goal_raise!
    redirect_to habit_path(@habit), notice: "Okay — keeping this goal for today."
  end

  private

  def set_habit
    @habit = current_user.habits.find(params[:id])
  end

  def habit_params
    params.require(:habit).permit(
      :name, :description, :points, :frequency, :active, :unit, :show_on_home, :position,
      :stat_type, :goal, :min_value, :max_value
    )
  end

  # When "Enable a target" is off, the form still may post empty type fields —
  # force Better Than Yesterday with no stretch / range targets.
  def clear_targets_unless_configured!
    has_stretch = @habit.goal.present?
    has_range = @habit.min_value.present? || @habit.max_value.present?

    if @habit.standard?
      @habit.goal = nil
      return if has_range

      @habit.stat_type = "growth"
    elsif !has_stretch
      @habit.goal = nil
      @habit.min_value = nil
      @habit.max_value = nil
      @habit.stat_type = "growth"
    end
  end
end
