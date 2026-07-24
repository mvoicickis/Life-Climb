class PagesController < ApplicationController
  allow_unauthenticated_access only: :home
  layout "landing"

  def home
    redirect_to dashboard_path if authenticated?
  end
end
