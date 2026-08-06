# frozen_string_literal: true

module Notifications
  class QuickAddsController < BaseController
    def create
      result = Battles::QuickAddToday.call(
        user: @user,
        category: params[:category]
      )
      render json: {
        ok: true,
        message: I18n.t("notifications.actions.quick_add_ok", title: result.title),
        title: result.title,
        category: result.category
      }
    rescue Battles::QuickAddToday::Error => e
      render json: { ok: false, error: e.message }, status: :unprocessable_entity
    rescue ActiveRecord::RecordInvalid => e
      render json: { ok: false, error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end
end
