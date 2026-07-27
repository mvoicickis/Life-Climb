# frozen_string_literal: true

module Developer
  class ToolsController < BaseController
    # POST /developer/tools/restart_new_player_experience
    def restart_new_player_experience
      Developer::RestartNewPlayerExperience.call(user: current_user)
      session.delete(:v2_onboarding)
      session.delete(:onboarding_draft)

      redirect_to v2_onboarding_path(step: "welcome"),
                  notice: t("developer.tools.restart_npe_done"),
                  status: :see_other
    end
  end
end
