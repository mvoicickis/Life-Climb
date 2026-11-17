# frozen_string_literal: true

module ClimbTogether
  class HighFivesController < ApplicationController
    def create
      day = PartnerDayWins.call(viewer: current_user)
      unless day&.partner && day.count.positive? && day.battle.present?
        head :unprocessable_entity and return
      end

      if day.cheered
        @partner_day_wins = day
        @not_saved = false
        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to dashboard_path }
        end
        return
      end

      begin
        HighFives::Create.call(
          from: current_user,
          battle: day.battle,
          daily_todo: day.daily_todo
        )
        @partner_day_wins = PartnerDayWins.call(viewer: current_user)
        @not_saved = false
      rescue Error
        @partner_day_wins = day
        @not_saved = true
      end

      respond_to do |format|
        format.turbo_stream do
          render status: (@not_saved ? :unprocessable_entity : :ok)
        end
        format.html do
          if @not_saved
            redirect_to dashboard_path, alert: t("climb_together.partner.not_saved")
          else
            redirect_to dashboard_path
          end
        end
      end
    end
  end
end
