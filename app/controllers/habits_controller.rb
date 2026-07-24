class HabitsController < ApplicationController
  before_action :set_habit, only: %i[ show edit update destroy ]

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
      show_on_home: true
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

  private

  def set_habit
    @habit = current_user.habits.find(params[:id])
  end

  def habit_params
    params.require(:habit).permit(
      :name, :description, :points, :frequency, :active, :unit, :show_on_home, :position
    )
  end
end
