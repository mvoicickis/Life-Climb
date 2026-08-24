# frozen_string_literal: true

class LifeJourneyPlantDestinationsController < ApplicationController
  before_action :require_planning_v2
  before_action :set_journey
  before_action :set_goal

  def create
    result = Strategy::PlantDestinationFlag.call(
      user: current_user,
      journey: @journey,
      goal: @goal,
      title: params.require(:title)
    )

    redirect_to life_journey_path(
                  @journey,
                  goal_id: result.goal.id,
                  plan_id: result.plan.id
                ),
                notice: (result.created? ? t("strategy.rpg.trail.destination_planted") : nil),
                status: :see_other
  rescue ArgumentError => e
    redirect_to life_journey_path(@journey, goal_id: @goal.id),
                alert: e.message,
                status: :see_other
  end

  private

  def set_journey
    @journey = current_user.life_journeys.active.find(params.require(:life_journey_id))
  end

  def set_goal
    @goal = current_user.strategy_goals.for_kind("goal").roots.find_by!(
      id: params.require(:goal_id),
      life_journey_id: @journey.id
    )
  end

  def require_planning_v2
    return if current_user.planning_v2?

    redirect_to life_area_selections_path
  end
end
