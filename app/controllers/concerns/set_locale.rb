module SetLocale
  extend ActiveSupport::Concern

  included do
    before_action :set_locale
  end

  private

  def set_locale
    locale = requested_locale
    I18n.locale = locale
    session[:locale] = locale
    cookies.permanent[:locale] = {
      value: locale,
      httponly: true,
      same_site: :lax,
      secure: Rails.env.production?
    }
  end

  def requested_locale
    candidate =
      params[:locale].presence ||
      signed_in_user_locale ||
      session[:locale].presence ||
      cookies[:locale].presence ||
      I18n.default_locale
    candidate = candidate.to_s.to_sym
    I18n.available_locales.include?(candidate) ? candidate : I18n.default_locale
  end

  def signed_in_user_locale
    Current.user&.locale.presence
  end
end
