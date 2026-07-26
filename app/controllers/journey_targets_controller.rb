# frozen_string_literal: true

class JourneyTargetsController < ApplicationController
  before_action :require_planning_v2
  before_action :set_journey, only: :create
  before_action :set_target, only: %i[ log destroy ]

  def create
    target = @journey.journey_targets.new(target_params)
    target.user = current_user
    target.position = @journey.journey_targets.count
    target.kind = target.kind.presence || "oneshot"
    target.target_value = 1 if target.oneshot? && target.target_value.to_f <= 0
    if target.save
      redirect_back fallback_location: life_journey_path(@journey), notice: t("journeys.climb.target_saved")
    else
      redirect_back fallback_location: life_journey_path(@journey),
                    alert: target.errors.full_messages.to_sentence.presence || t("journeys.climb.target_need_title")
    end
  end

  def log
    amount = params[:amount]
    @target.log!(amount: amount)
    notice =
      if @target.completed?
        t("journeys.climb.target_completed", title: @target.title)
      else
        t("journeys.climb.target_logged", title: @target.title)
      end
    redirect_back fallback_location: dashboard_path, notice: notice
  rescue ArgumentError => e
    redirect_back fallback_location: dashboard_path, alert: e.message
  end

  def destroy
    journey = @target.life_journey
    @target.destroy!
    redirect_back fallback_location: life_journey_path(journey), notice: t("journeys.climb.target_saved")
  end

  private

  def set_journey
    @journey = current_user.life_journeys.find(params[:life_journey_id])
  end

  def set_target
    @target = current_user.journey_targets.find(params[:id])
  end

  def target_params
    raw = params.require(:journey_target).permit(:title, :kind, :target_value, :unit, :tags)
    tags = raw[:tags]
    raw[:tags] = tags.to_s.split(/[,\s]+/) if tags.is_a?(String)
    raw
  end

  def require_planning_v2
    return if current_user.planning_v2?

    redirect_to life_area_selections_path, alert: t("journeys.need_v2")
  end
end
