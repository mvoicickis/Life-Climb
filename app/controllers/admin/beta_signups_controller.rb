# frozen_string_literal: true

module Admin
  class BetaSignupsController < BaseController
    FILTER_ALL = "all"
    FILTER_ANDROID = DeviceFromUserAgent::DEVICE_ANDROID.to_s
    FILTERS = [ FILTER_ALL, FILTER_ANDROID ].freeze

    def index
      @filter = permitted_filter
      scope = filtered_scope
      @total_count = scope.count
      @beta_signups = scope.limit(5_000)
      @copy_emails = scope.pluck(:email).join(", ")

      respond_to do |format|
        format.html
        format.csv { send_data export_csv(scope), filename: "lifepoints-beta-emails-#{Date.current}.csv" }
      end
    end

    def destroy
      BetaSignup.find(params[:id]).destroy!
      redirect_to admin_beta_signups_path(filter: permitted_filter),
                  notice: t("admin.beta_signups.deleted")
    end

    private

    def permitted_filter
      filter = params[:filter].to_s
      FILTERS.include?(filter) ? filter : FILTER_ALL
    end

    def filtered_scope
      scope = BetaSignup.newest_first
      scope = scope.where(device: FILTER_ANDROID) if permitted_filter == FILTER_ANDROID
      scope
    end

    def export_csv(scope)
      require "csv"

      CSV.generate(headers: true) do |csv|
        csv << %w[email signed_up_at source_path device]
        scope.find_each do |signup|
          csv << [
            signup.email,
            signup.created_at.iso8601,
            signup.source_path,
            signup.device
          ]
        end
      end
    end
  end
end