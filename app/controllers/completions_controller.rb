class CompletionsController < ApplicationController
  def create
    @habit = current_user.habits.find(params[:habit_id])
    @completion = current_user.completions.build(habit: @habit, completed_on: Date.current)

    if @completion.save
      Today::OvershootBonus.sync!(user: current_user)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to dashboard_path, notice: "+#{@habit.points} points!" }
      end
    else
      redirect_to dashboard_path, alert: @completion.errors.full_messages.to_sentence
    end
  end

  def destroy
    completion = current_user.completions.find(params[:id])
    completion.destroy!
    Today::OvershootBonus.sync!(user: current_user)
    redirect_to dashboard_path, notice: t("habits.undone"), status: :see_other
  rescue ActiveRecord::RecordNotFound
    redirect_to dashboard_path, status: :see_other
  end
end
