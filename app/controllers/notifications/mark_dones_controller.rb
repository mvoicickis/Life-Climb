# frozen_string_literal: true

module Notifications
  class MarkDonesController < BaseController
    def create
      result = Battles::MarkDoneFromNotification.call(
        user: @user,
        session: session,
        category: params[:category]
      )

      if result.nothing_to_mark
        return render json: {
          ok: true,
          nothing_to_mark: true,
          message: I18n.t("notifications.actions.mark_done_none")
        }
      end

      render json: {
        ok: true,
        message: I18n.t("notifications.actions.mark_done_ok", title: result.title),
        title: result.title,
        nothing_to_mark: false
      }
    rescue Battles::MarkDoneFromNotification::Error, ArgumentError => e
      render json: { ok: false, error: e.message }, status: :unprocessable_entity
    rescue ActiveRecord::RecordInvalid => e
      render json: { ok: false, error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end
end
