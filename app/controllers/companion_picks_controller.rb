# frozen_string_literal: true

class CompanionPicksController < ApplicationController
  def update
    unless current_user.needs_companion_pick?
      head :no_content and return
    end

    if current_user.update(companion_pick_params)
      current_user.mark_companion_pick_done! if current_user.character_chosen?

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back fallback_location: dashboard_path, notice: t("settings.character_updated") }
      end
    else
      head :unprocessable_entity
    end
  end

  private

  def companion_pick_params
    params.require(:user).permit(:character)
  end
end
