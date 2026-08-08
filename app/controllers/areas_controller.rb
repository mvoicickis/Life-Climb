# frozen_string_literal: true

class AreasController < ApplicationController
  before_action :set_area, only: %i[ update destroy ]

  def index
    redirect_to habits_path(anchor: "areas"), status: :see_other
  end

  def create
    area = current_user.areas.build(area_params)
    if area.save
      redirect_to habits_path(anchor: "areas"), notice: t("areas.created"), status: :see_other
    else
      redirect_to habits_path(anchor: "areas"), alert: area.errors.full_messages.to_sentence, status: :see_other
    end
  end

  def update
    if @area.update(area_params)
      redirect_to habits_path(anchor: "areas"), notice: t("areas.updated"), status: :see_other
    else
      redirect_to habits_path(anchor: "areas"), alert: @area.errors.full_messages.to_sentence, status: :see_other
    end
  end

  def destroy
    @area.destroy!
    redirect_to habits_path(anchor: "areas"), notice: t("areas.removed"), status: :see_other
  end

  private

  def set_area
    @area = current_user.areas.find(params[:id])
  end

  def area_params
    params.require(:area).permit(:name, :position)
  end
end
