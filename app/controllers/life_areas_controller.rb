class LifeAreasController < ApplicationController
  before_action :set_life_area

  def show
    @dream = @life_area.dream
    @goal = @life_area.active_goal
    @building = @life_area.active_building
    @mission = current_mission_for(@building)

    if sheet_request?
      render partial: "life_areas/sheet",
             locals: {
               life_area: @life_area,
               goal: @goal,
               building: @building,
               mission: @mission
             } and return
    end
  end

  def update
    if @life_area.update(life_area_params)
      ensure_goal! if params[:goal_title].present?
      redirect_to life_area_path(@life_area), notice: t("life_parts.saved")
    else
      @dream = @life_area.dream
      @goal = @life_area.active_goal
      @building = @life_area.active_building
      render :show, status: :unprocessable_entity
    end
  end

  def focus
    goal = @life_area.active_goal
    unless goal
      redirect_to life_area_path(@life_area), alert: t("life_parts.need_goal") and return
    end

    building = @life_area.active_building
    unless building
      step = goal.steps.ordered.first ||
             current_user.steps.create!(goal: goal, title: t("life_parts.default_step"), position: 0)
      building = current_user.buildings.create!(
        step: step,
        title: params[:building_title].presence || @life_area.short_label,
        status: "active"
      )
    end

    current_user.update!(focus_building: building)
    redirect_to dashboard_path, notice: t("life_parts.focus_set", part: @life_area.short_label)
  end

  def closer
    if @life_area.bump_closer!
      redirect_to dashboard_path, notice: t("today.closer_bumped")
    else
      redirect_to dashboard_path, notice: t("today.closer_max")
    end
  end

  private

  def set_life_area
    @life_area = current_user.life_areas.find(params[:id])
  end

  def sheet_request?
    ActiveModel::Type::Boolean.new.cast(params[:sheet]) ||
      request.headers["Turbo-Frame"] == "life_area_sheet"
  end

  def current_mission_for(building)
    return unless building

    building.today_actions.for_day(Date.current).incomplete.ordered.first ||
      building.today_actions.for_day(Date.current).ordered.first
  end

  def life_area_params
    params.require(:life_area).permit(:ambition, :present_scene, :closer_score)
  end

  def ensure_goal!
    title = params[:goal_title].to_s.strip
    return if title.blank?

    goal = @life_area.active_goal
    if goal
      goal.update!(title: title)
    else
      current_user.goals.create!(
        dream: @life_area.dream,
        life_area: @life_area,
        title: title,
        position: current_user.goals.count
      )
    end
  end
end
