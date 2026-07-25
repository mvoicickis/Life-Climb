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
    cookies.permanent[:locale] = locale
  end

  def requested_locale
    candidate = params[:locale].presence || session[:locale].presence || cookies[:locale].presence || I18n.default_locale
    candidate = candidate.to_s.to_sym
    I18n.available_locales.include?(candidate) ? candidate : I18n.default_locale
  end
end
