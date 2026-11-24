# frozen_string_literal: true

class FirstTipAcksController < ApplicationController
  def create
    key = params[:key].to_s
    unless User::FIRST_TIP_KEYS.include?(key)
      head :unprocessable_entity
      return
    end

    return head :no_content if read_only_impersonation?

    current_user.mark_first_tip_seen!(key)
    current_user.record_first_tip_shown_today!(key)
    head :no_content
  end
end
