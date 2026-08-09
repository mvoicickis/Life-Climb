# frozen_string_literal: true

class TodayCommitmentsController < ApplicationController
  def level_up
    journey = current_user.primary_focused_journey
    if journey && Today::Commitment.level_up_preset!(journey)
      redirect_to dashboard_path, notice: t("dash.commitment.level_up_done", name: journey.commitment_name)
    else
      redirect_to dashboard_path
    end
  end

  def decline
    journey = current_user.primary_focused_journey
    Today::Commitment.decline_level_up!(journey) if journey
    redirect_to dashboard_path
  end
end
