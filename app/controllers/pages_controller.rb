class PagesController < ApplicationController
  allow_unauthenticated_access only: :home
  layout "landing"

  def home
    return unless authenticated?
    redirect_to(current_user.needs_onboarding? ? onboarding_path : dashboard_path)
  end
end
