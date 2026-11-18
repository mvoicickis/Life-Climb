# frozen_string_literal: true

module ClimbTogether
  class PagesController < ApplicationController
    def show
      @side_by_side = SideBySide.call(viewer: current_user)
      redirect_to settings_path, status: :see_other if @side_by_side.blank?
    end
  end
end
