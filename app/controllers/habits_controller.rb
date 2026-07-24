class HabitsController < ApplicationController
  before_action :set_habit, only: %i[ show edit update destroy raise_goal decline_goal_raise ]

  def index
    @habits = current_user.habits.ordered
  end

  def show
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

    if @habit.save
      redirect_to habits_path, notice: "Saved."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @habit.update(habit_params)
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
      redirect_to habit_path(@habit), notice: "Goal raised to #{@habit.goal.to_i == @habit.goal ? @habit.goal.to_i : @habit.goal}."
    else
      redirect_to habit_path(@habit), alert: "Set a growth goal first."
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
end
