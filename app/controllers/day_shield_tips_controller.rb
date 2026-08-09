# frozen_string_literal: true

class DayShieldTipsController < ApplicationController
  def destroy
    current_user.mark_day_shield_tip_done!
    redirect_to dashboard_path, status: :see_other
  end
end
