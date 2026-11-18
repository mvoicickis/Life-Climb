# frozen_string_literal: true

module Admin
  class TestersController < BaseController
    def index
      @filter = Testers::FILTERS.include?(params[:filter].to_s) ? params[:filter].to_s : Testers::FILTER_NEEDS_MESSAGE
      @berlin_today = Testers.berlin_today
      @climbers_month = climbers_month_start
      @climbers_by_day = Testers.counts_by_day(month: @climbers_month)

      if turbo_frame_request? && request.headers["Turbo-Frame"] == "climbers_calendar"
        render partial: "admin/testers/climbers_calendar", locals: climbers_calendar_locals
        return
      end

      @today_counts = today_climber_counts
      @rows = Testers.call(filter: @filter)
    end

    private

    def climbers_month_start
      cap = @berlin_today.beginning_of_month
      raw = params[:climbers_month].presence
      return cap if raw.blank?

      year, month = raw.split("-", 2).map(&:to_i)
      date = Date.new(year, month, 1)
      date > cap ? cap : date
    rescue ArgumentError, Date::Error
      cap
    end

    def today_climber_counts
      if @climbers_month.year == @berlin_today.year && @climbers_month.month == @berlin_today.month
        @climbers_by_day[@berlin_today] || { testers: 0, admins: 0 }
      else
        Testers.counts_by_day(month: @berlin_today)[@berlin_today] || { testers: 0, admins: 0 }
      end
    end

    def climbers_calendar_locals
      {
        counts_by_day: @climbers_by_day,
        calendar_month: @climbers_month,
        berlin_today: @berlin_today,
        filter: @filter
      }
    end
  end
end
