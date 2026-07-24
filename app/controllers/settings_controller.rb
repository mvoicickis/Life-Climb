class SettingsController < ApplicationController
  def show
    @home_habits = current_user.home_board_habits
    @all_habits = current_user.habits.active.ordered
  end

  def update
    if current_user.update(settings_params)
      redirect_to settings_path, notice: "Home updated."
    else
      @home_habits = current_user.home_board_habits
      @all_habits = current_user.habits.active.ordered
      render :show, status: :unprocessable_entity
    end
  end

  def reorder
    ids = Array(params[:habit_ids]).map(&:to_i)
    habits = current_user.habits.where(id: ids).index_by(&:id)

    ActiveRecord::Base.transaction do
      ids.each_with_index do |id, index|
        habit = habits[id]
        next unless habit

        habit.update!(position: index + 1)
      end
    end

    head :ok
  end

  def update_habit
    habit = current_user.habits.find(params[:id])
    habit.update!(show_on_home: ActiveModel::Type::Boolean.new.cast(params[:show_on_home]))
    redirect_to settings_path, notice: "Home list updated."
  end

  private

  def settings_params
    params.require(:user).permit(:home_stat_count)
  end
end
