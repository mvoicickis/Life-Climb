module Admin
  class BaseController < ApplicationController
    layout "admin"
    before_action :require_admin

    private

    def require_admin
      return if current_user&.admin?

      redirect_to dashboard_path, alert: "Admin only."
    end
  end
end
