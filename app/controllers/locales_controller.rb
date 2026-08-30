class LocalesController < ApplicationController
  allow_unauthenticated_access only: :update

  def update
    locale = params[:locale].to_s.to_sym
    locale = I18n.default_locale unless I18n.available_locales.include?(locale)

    session[:locale] = locale
    cookies.permanent[:locale] = {
      value: locale,
      httponly: true,
      same_site: :lax,
      secure: Rails.env.production?
    }
    I18n.locale = locale

    if authenticated? && Current.user && !impersonating?
      Current.user.update!(locale: locale.to_s)
    end

    redirect_back fallback_location: (authenticated? ? dashboard_path : root_path)
  end
end
