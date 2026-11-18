# frozen_string_literal: true

module Admin
  class TestersController < BaseController
    def index
      @filter = Testers::FILTERS.include?(params[:filter].to_s) ? params[:filter].to_s : Testers::FILTER_NEEDS_MESSAGE
      @rows = Testers.call(filter: @filter)
    end
  end
end
