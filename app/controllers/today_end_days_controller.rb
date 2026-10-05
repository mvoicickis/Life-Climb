# frozen_string_literal: true

class TodayEndDaysController < ApplicationController
  include Dashboard::TodaySurface

  def create
    @journey = current_user.primary_focused_journey
    unless @journey
      redirect_to dashboard_path, alert: t("dash.battlefield.need_journey"), status: :see_other
      return
    end

    assign_today_battle_surface!(reconcile: false)

    if @battle_open_count.positive?
      redirect_to dashboard_path, alert: t("dash.battlefield.end_day_blocked"), status: :see_other
      return
    end

    if truthy_param?(params[:handoff])
      handoff = Strategy::Handoff.for(user: current_user, journey: @journey)
      unless handoff&.dig(:href).present?
        redirect_to dashboard_path, alert: t("dash.battlefield.need_journey"), status: :see_other
        return
      end

      Today::BattlefieldDay.end!(session)
      redirect_to handoff[:href], status: :see_other
      return
    end

    if truthy_param?(params[:plan_on_mountain])
      project = Today::EndOfDay.planning_project(user: current_user, journey: @journey)
      unless project
        redirect_to dashboard_path, alert: t("dash.end_of_day.invalid_camp"), status: :see_other
        return
      end

      Today::BattlefieldDay.end!(session)
      redirect_to life_journey_path(@journey, open_camp: project.id), status: :see_other
      return
    end

    Today::EodFlow.acknowledge!(session)
    redirect_to dashboard_path, status: :see_other
  end

  def destroy
    Today::BattlefieldDay.reset!(session)
    redirect_to dashboard_path, status: :see_other
  end

  private

  def truthy_param?(value)
    value.present? && value.to_s != "0" && value.to_s != "false"
  end
end
