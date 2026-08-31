# frozen_string_literal: true

module Developer
  class ToolsController < BaseController
    # POST /developer/tools/restart_new_player_experience
    def restart_new_player_experience
      Developer::RestartNewPlayerExperience.call(user: current_user)
      session.delete(:v2_onboarding)
      session.delete(:onboarding_draft)
      session.delete(:project_check_ids)
      session.delete(:battle_angle_project_id)
      session.delete(Today::EodFlow::ACK_SESSION_KEY)
      session.delete(Today::BattlefieldDay::SESSION_KEY)

      redirect_to v2_onboarding_path(step: "character"),
                  notice: t("developer.tools.restart_npe_done"),
                  status: :see_other
    end
  end
end
