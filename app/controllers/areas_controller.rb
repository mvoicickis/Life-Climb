# frozen_string_literal: true

class AreasController < ApplicationController
  before_action :set_area, only: %i[ update destroy move ]

  def index
    redirect_to habits_path(anchor: "areas"), status: :see_other
  end

  def create
    area = current_user.areas.build(area_params)
    if area.save
      redirect_after_area notice: t("areas.created")
    else
      redirect_after_area alert: area.errors.full_messages.to_sentence
    end
  end

  def update
    if @area.update(area_params)
      redirect_after_area notice: t("areas.updated")
    else
      redirect_after_area alert: @area.errors.full_messages.to_sentence
    end
  end

  def destroy
    @area.destroy!
    redirect_after_area notice: t("areas.removed")
  end

  def move
    if @area.move!(params[:direction])
      redirect_after_area notice: t("areas.moved")
    else
      redirect_after_area alert: t("areas.move_failed")
    end
  end

  private

  def set_area
    @area = current_user.areas.find(params[:id])
  end

  def area_params
    params.require(:area).permit(:name, :position)
  end

  def redirect_after_area(**flash)
    if params[:return_to].to_s == "journey"
      redirect_to life_points_path, **flash, status: :see_other
    else
      redirect_to habits_path(anchor: "areas"), **flash, status: :see_other
    end
  end
end
