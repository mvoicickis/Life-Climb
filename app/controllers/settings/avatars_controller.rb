# frozen_string_literal: true

module Settings
  # You page social animal avatar (Climb together). Separate from mountain companion.
  class AvatarsController < ApplicationController
    def update
      if current_user.update(avatar_params)
        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to settings_path }
        end
      else
        respond_to do |format|
          format.turbo_stream { head :unprocessable_entity }
          format.html { redirect_to settings_path, alert: t("climb_together.avatar.not_saved") }
        end
      end
    end

    private

    def avatar_params
      params.fetch(:user, {}).permit(:avatar_key)
    end
  end
end
