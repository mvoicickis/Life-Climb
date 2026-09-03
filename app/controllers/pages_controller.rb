class PagesController < ApplicationController
  allow_unauthenticated_access only: :home
  layout "landing"

  def home
    if authenticated?
      redirect_to(current_user.needs_onboarding? ? onboarding_path : dashboard_path)
      return
    end

    Analytics::Track.call(name: "landing_viewed")
  end
end
