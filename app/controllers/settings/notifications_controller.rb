# frozen_string_literal: true

module Settings
  class NotificationsController < ApplicationController
    before_action :set_preference

    def show
    end

    def update
      if @preference.update(preference_params)
        respond_to do |format|
          format.html { redirect_to settings_notifications_path, notice: t("settings.notifications.updated") }
          format.json { render json: { ok: true, time_zone: @preference.time_zone } }
        end
      else
        respond_to do |format|
          format.html { render :show, status: :unprocessable_entity }
          format.json { render json: { ok: false, errors: @preference.errors.full_messages }, status: :unprocessable_entity }
        end
      end
    end

    private

    def set_preference
      @preference = current_user.notification_preference!
    end

    def preference_params
      permitted = params.require(:notification_preference).permit(
        :frequency,
        :intensity,
        :quiet_hours_start,
        :quiet_hours_end,
        :time_zone,
        :vacation_until,
        :vacation_paused,
        :win_notifications_enabled,
        :stuck_notifications_enabled
      )

      %i[quiet_hours_start quiet_hours_end vacation_until time_zone].each do |key|
        permitted[key] = nil if permitted.key?(key) && permitted[key].blank?
      end

      permitted
    end
  end
end
