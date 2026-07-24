class SettingsController < ApplicationController
  def show
    @home_habits = current_user.home_board_habits
  end

  def update
    if current_user.update(settings_params)
      redirect_to settings_path, notice: "Saved."
    else
      @home_habits = current_user.home_board_habits
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

  private

  def settings_params
    params.require(:user).permit(:home_stat_count)
  end
end
