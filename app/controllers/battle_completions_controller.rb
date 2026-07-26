# frozen_string_literal: true

class BattleCompletionsController < ApplicationController
  def create
    result = Battles::CompleteDay.call(user: current_user)
    Journeys::SyncClimbFromToday.call(user: current_user)
    if result.ok
      redirect_to dashboard_path, notice: result.message
    else
      redirect_to dashboard_path, alert: result.message
    end
  rescue Missions::Complete::Error => e
    redirect_to dashboard_path, alert: e.message
  end
end
