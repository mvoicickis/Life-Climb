# frozen_string_literal: true

module Admin
  class TestersController < BaseController
    def index
      @rows = Testers.call
    end
  end
end
