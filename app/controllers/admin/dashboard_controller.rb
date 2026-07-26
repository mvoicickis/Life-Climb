# frozen_string_literal: true

module Admin
  class DashboardController < BaseController
    def show
      @metrics = Admin::Metrics.call
      @cards = @metrics[:cards]
      @charts = @metrics[:charts]
      @recent_users = @metrics[:recent_users]
      @recent_feedbacks = @metrics[:recent_feedbacks]
      @recent_ledgers = @metrics[:recent_ledgers]
    end
  end
end
