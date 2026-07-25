class TodayActionsController < ApplicationController
  def create
    building = current_user.focus_building || current_user.buildings.active.order(:id).first
    unless building
      redirect_to onboarding_path, alert: t("today.need_building") and return
    end

    action = current_user.today_actions.new(
      building: building,
      title: params.require(:today_action).permit(:title)[:title],
      scheduled_on: Date.current,
      position: building.today_actions.for_day(Date.current).count
    )

    if action.save
      destination = safe_post_action_redirect
      redirect_to destination, notice: t("today.action_added")
    else
      redirect_to dashboard_path, alert: action.errors.full_messages.to_sentence
    end
  end

  def complete
    action = current_user.today_actions.find(params[:id])
    if action.completed?
      redirect_to dashboard_path and return
    end

    action.update!(completed_at: Time.current)
    LifePointsAward.new(current_user).for_action!(action)
    redirect_to (safe_post_action_redirect || dashboard_path), notice: t("today.action_done", points: LifePointsAward::ACTION)
  end

  private

  def safe_post_action_redirect
    path = request.referer.to_s
    uri = URI.parse(path) rescue nil
    return building_path if uri && uri.path == building_path
    return dashboard_path if uri && uri.path == dashboard_path

    dashboard_path
  end
end
