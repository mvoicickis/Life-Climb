class LocalesController < ApplicationController
  allow_unauthenticated_access only: :update

  def update
    locale = params[:locale].to_s.to_sym
    locale = I18n.default_locale unless I18n.available_locales.include?(locale)

    session[:locale] = locale
    cookies.permanent[:locale] = locale
    I18n.locale = locale

    redirect_back fallback_location: (authenticated? ? dashboard_path : root_path)
  end
end
