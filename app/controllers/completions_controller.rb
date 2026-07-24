class CompletionsController < ApplicationController
  def create
    @habit = current_user.habits.find(params[:habit_id])
    @completion = current_user.completions.build(habit: @habit, completed_on: Date.current)

    if @completion.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to dashboard_path, notice: "+#{@habit.points} points!" }
      end
    else
      redirect_to dashboard_path, alert: @completion.errors.full_messages.to_sentence
    end
  end
end
