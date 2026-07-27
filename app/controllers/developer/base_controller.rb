# frozen_string_literal: true

module Developer
  class BaseController < ApplicationController
    skip_onboarding_check
    before_action :require_developer!

    private

    def require_developer!
      unless current_user
        request_authentication
        return
      end

      promote_configured_developer_if_needed!

      return if DeveloperAccess.allowed?(current_user) && !impersonating?

      deny_developer_access!
    end

    def promote_configured_developer_if_needed!
      return unless DeveloperAccess.email_allowed?(current_user.email_address)
      return if current_user.read_attribute(:developer)

      current_user.update_columns(developer: true)
    end

    def deny_developer_access!
      head :forbidden
    end
  end
end
