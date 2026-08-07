# frozen_string_literal: true

module Notifications
  class SnoozesController < BaseController
    SNOOZE_DURATION = 4.hours

    def create
      preference = @user.notification_preference!
      preference.update!(snoozed_until: Time.current + SNOOZE_DURATION)

      render json: {
        ok: true,
        message: I18n.t("notifications.actions.snooze_ok"),
        snoozed_until: preference.snoozed_until.iso8601
      }
    rescue ActiveRecord::RecordInvalid => e
      render json: { ok: false, error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end
end
