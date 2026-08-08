class HabitsController < ApplicationController
  before_action :set_habit, only: %i[ show edit update destroy raise_goal decline_goal_raise ]
  before_action :load_journeys, only: %i[ new create edit update ]
  before_action :load_areas, only: %i[ index new create edit update show ]

  def index
    @habits = current_user.habits.ordered.includes(:life_journey, :area)
    @areas = current_user.areas.ordered.includes(habits: :area)
    @unfiled_habits = @habits.select { |habit| habit.area_id.blank? }
  end

  def show
    insights = DashboardInsights.new(current_user, trackers: [ @habit ])
    @share_worthy = insights.personal_record?(@habit) || insights.big_boost?(@habit)
    @milestone_label =
      if insights.personal_record?(@habit)
        I18n.t("habits.milestone_record")
      elsif insights.big_boost?(@habit)
        I18n.t("habits.milestone_boost")
      end
    @sparkline = @habit.sparkline_amounts(days: 14)
    @improvement_projects = @habit.improvement_projects.for_kind("project").ordered.includes(:life_journey)
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
    return_to = params[:return_to].to_s

    if @habit.save
      if return_to == "show"
        redirect_to habit_path(@habit), notice: "Saved."
      else
        redirect_to habits_path, notice: "Saved."
      end
    elsif return_to == "show"
      @sparkline = @habit.sparkline_amounts(days: 14)
      @improvement_projects = @habit.improvement_projects.for_kind("project").ordered.includes(:life_journey)
      render :show, status: :unprocessable_entity
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @habit.destroy!
    flash[:turbo_clear_cache] = true
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

  def load_journeys
    @journeys = current_user.life_journeys.active.order(:title, :id)
  end

  def load_areas
    @areas = current_user.areas.ordered
  end

  def habit_params
    raw = params.require(:habit).permit(
      :name, :description, :points, :frequency, :active, :unit, :show_on_home, :position,
      :stat_type, :goal, :min_value, :max_value, :life_journey_id, :identity_label,
      :area_id, :state, :state_label_good, :state_label_attention
    )
    # Clamp client-supplied LP rewards — habits are not a free AP faucet.
    if raw[:points].present?
      raw[:points] = raw[:points].to_i.clamp(1, 50)
    end
    raw[:life_journey_id] = raw[:life_journey_id].presence
    raw[:identity_label] = raw[:identity_label].presence
    raw[:area_id] = raw[:area_id].presence
    raw[:state] = raw[:state].presence
    raw[:state_label_good] = raw[:state_label_good].presence
    raw[:state_label_attention] = raw[:state_label_attention].presence
    raw
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
