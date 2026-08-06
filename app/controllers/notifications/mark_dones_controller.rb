# frozen_string_literal: true

module Notifications
  class MarkDonesController < BaseController
    def create
      result = Battles::MarkDoneFromNotification.call(
        user: @user,
        session: session,
        category: params[:category]
      )
      message =
        if result.created
          I18n.t("notifications.actions.mark_done_created_ok", title: result.title)
        else
          I18n.t("notifications.actions.mark_done_ok", title: result.title)
        end

      render json: {
        ok: true,
        message: message,
        title: result.title,
        created: result.created
      }
    rescue Battles::QuickAddToday::Error, Battles::MarkDoneFromNotification::Error, ArgumentError => e
      render json: { ok: false, error: e.message }, status: :unprocessable_entity
    rescue ActiveRecord::RecordInvalid => e
      render json: { ok: false, error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end
end
