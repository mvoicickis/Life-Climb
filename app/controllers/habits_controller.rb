class HabitsController < ApplicationController
  before_action :set_habit, only: %i[ show edit update destroy ]

  def index
    @habits = current_user.habits.order(active: :desc, name: :asc)
  end

  def show
  end

  def new
    @habit = current_user.habits.build(points: 5, frequency: "daily", active: true)
  end

  def create
    @habit = current_user.habits.build(habit_params)

    if @habit.save
      redirect_to habits_path, notice: "Habit created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @habit.update(habit_params)
      redirect_to habits_path, notice: "Habit updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @habit.destroy
    redirect_to habits_path, notice: "Habit deleted.", status: :see_other
  end

  private

  def set_habit
    @habit = current_user.habits.find(params[:id])
  end

  def habit_params
    params.require(:habit).permit(:name, :description, :points, :frequency, :active)
  end
end
