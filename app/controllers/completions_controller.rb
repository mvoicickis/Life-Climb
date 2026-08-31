class CompletionsController < ApplicationController
  include MountainSheetRefresh
  include Dashboard::TodaySurface

  before_action :verify_mountain_context!, if: :mountain_return?

  def create
    @habit = current_user.habits.find(params[:habit_id])
    if @habit.completed_today?
      return render_existing_completion
    end

    @completion = current_user.completions.build(habit: @habit, completed_on: Date.current)

    if @completion.save
      Today::OvershootBonus.sync!(user: current_user)
      assign_today_habit_stream! unless mountain_return?
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to after_completion_path, notice: "+#{@habit.points} points!" }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          if mountain_return?
            flash.now[:alert] = @completion.errors.full_messages.to_sentence
            render :create, status: :unprocessable_entity
          else
            redirect_to dashboard_path, alert: @completion.errors.full_messages.to_sentence
          end
        end
        format.html { redirect_to after_completion_path, alert: @completion.errors.full_messages.to_sentence }
      end
    end
  end

  def destroy
    @completion = current_user.completions.find(params[:id])
    @habit = @completion.habit
    @completion.destroy!
    Today::OvershootBonus.sync!(user: current_user)
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to after_completion_path, notice: t("habits.undone"), status: :see_other }
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to dashboard_path, status: :see_other
  end

  private

  def render_existing_completion
    Today::OvershootBonus.sync!(user: current_user)
    assign_mountain_sheet_for_base_camp! if mountain_return?
    assign_today_habit_stream! unless mountain_return?

    respond_to do |format|
      format.turbo_stream { render :create }
      format.html { redirect_to after_completion_path }
    end
  end

  def mountain_return?
    params[:return_to].to_s == "mountain"
  end

  def verify_mountain_context!
    assign_mountain_sheet_for_base_camp!
  rescue ActiveRecord::RecordNotFound
    redirect_to dashboard_path, alert: t("dash.battle_angles.invalid"), status: :see_other
  end

  def after_completion_path
    return mountain_after_completion_path if mountain_return?

    dashboard_path
  end

  def mountain_after_completion_path
    journey = current_user.life_journeys.find_by(id: params[:life_journey_id])
    return dashboard_path if journey.blank?

    life_journey_path(
      journey,
      goal_id: params[:goal_id].presence,
      plan_id: params[:plan_id].presence
    )
  end
end
