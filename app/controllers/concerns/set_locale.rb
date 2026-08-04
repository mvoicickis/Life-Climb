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
      browser_preferred_locale ||
      I18n.default_locale
    candidate = candidate.to_s.to_sym
    I18n.available_locales.include?(candidate) ? candidate : I18n.default_locale
  end

  def signed_in_user_locale
    Current.user&.locale.presence
  end

  # Parse Accept-Language (e.g. "lv-LV,lv;q=0.9,en;q=0.8") and return the
  # highest-q tag that matches a supported locale. Unsupported languages → nil.
  def browser_preferred_locale
    header = request.env["HTTP_ACCEPT_LANGUAGE"].to_s
    return if header.blank?

    preferred = header.split(",").filter_map do |part|
      tag, weight = part.strip.split(";q=", 2)
      next if tag.blank?

      code = tag.split(/[-_]/, 2).first.to_s.downcase
      next if code.blank?

      q = weight.present? ? weight.to_f : 1.0
      [ code.to_sym, q ]
    end

    preferred
      .sort_by { |(_, q)| -q }
      .map(&:first)
      .find { |code| I18n.available_locales.include?(code) }
  end
end
