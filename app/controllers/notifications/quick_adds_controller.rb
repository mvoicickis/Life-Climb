# frozen_string_literal: true

module Notifications
  class QuickAddsController < BaseController
    def create
      result =
        if params[:battle_id].present?
          battle = @user.strategy_goals.find_by(id: params[:battle_id])
          Battles::SurfaceOnToday.call(user: @user, battle: battle)
        else
          Battles::QuickAddToday.call(
            user: @user,
            category: params[:category]
          )
        end
      render json: {
        ok: true,
        message: I18n.t("notifications.actions.quick_add_ok", title: result.title),
        title: result.title,
        category: result.try(:category)
      }.compact
    rescue Battles::QuickAddToday::Error, Battles::SurfaceOnToday::Error => e
      render json: { ok: false, error: e.message }, status: :unprocessable_entity
    rescue ActiveRecord::RecordInvalid => e
      render json: { ok: false, error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end
end
