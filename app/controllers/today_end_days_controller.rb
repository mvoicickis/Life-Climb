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

    Today::BattlefieldDay.end!(session)
    redirect_to dashboard_path, status: :see_other
  end

  def destroy
    Today::BattlefieldDay.reset!(session)
    redirect_to dashboard_path, status: :see_other
  end
end
