# frozen_string_literal: true

module Admin
  class StatisticsController < BaseController
    def show
      @metrics = Admin::Metrics.call(lookback_days: 90)
      @cards = @metrics[:cards]
      @charts = @metrics[:charts]
      @excluded_users_count = @metrics[:excluded_users]

      respond_to do |format|
        format.html
        format.csv { send_data Admin::Metrics.export_csv(@cards), filename: "lifepoints-stats-#{Date.current}.csv" }
        format.json { render json: { cards: @cards, charts: @charts } }
      end
    end
  end
end
