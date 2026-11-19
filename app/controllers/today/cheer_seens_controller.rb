# frozen_string_literal: true

module Today
  # Marks a received HighFive as seen after the Today top-bar cheer morph.
  class CheerSeensController < ApplicationController
    before_action :require_authentication

    def create
      cheer = current_user.high_fives_received.find_by(id: params[:id])
      cheer&.mark_seen!
      head :no_content
    end
  end
end
