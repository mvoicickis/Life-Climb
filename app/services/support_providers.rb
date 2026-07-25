# frozen_string_literal: true

# Future-ready support providers. Enable via enabled: true and URL env vars.
# Adding a provider = one hash here + optional ENV — the Support page renders enabled ones.
module SupportProviders
  module_function

  PROVIDERS = [
    {
      id: :buy_me_a_coffee,
      kind: :primary,
      i18n_key: "support.providers.buy_me_a_coffee",
      url_env: "BUY_ME_A_COFFEE_URL",
      default_url: nil,
      enabled: true
    },
    {
      id: :become_supporter,
      kind: :secondary,
      i18n_key: "support.providers.become_supporter",
      url_env: "SUPPORT_SUPPORTER_URL",
      default_url: nil,
      enabled: false
    },
    {
      id: :sponsor_development,
      kind: :secondary,
      i18n_key: "support.providers.sponsor_development",
      url_env: "SUPPORT_SPONSOR_URL",
      # e.g. GitHub Sponsors
      default_url: nil,
      enabled: false
    },
    {
      id: :make_contribution,
      kind: :secondary,
      i18n_key: "support.providers.make_contribution",
      url_env: "SUPPORT_CONTRIBUTION_URL",
      # e.g. Stripe / PayPal / Patreon
      default_url: nil,
      enabled: false
    }
  ].freeze

  def all
    PROVIDERS.map { |p| hydrate(p) }
  end

  def enabled
    all.select { |p| p[:enabled] && p[:url].present? }
  end

  def primary
    enabled.find { |p| p[:kind] == :primary } || enabled.first
  end

  def coming_soon
    all.reject { |p| p[:enabled] && p[:url].present? }
  end

  def hydrate(provider)
    url = ENV[provider[:url_env].to_s].presence || provider[:default_url]
    if provider[:id] == :buy_me_a_coffee && url.blank?
      email = ENV.fetch("CONTACT_EMAIL", ENV.fetch("FEEDBACK_TO_EMAIL", "mvoicickis@gmail.com"))
      url = "mailto:#{email}?subject=#{ERB::Util.url_encode('Support LifePoints')}&body=#{ERB::Util.url_encode("Hi Mareks,\n\nI'd like to support LifePoints.\n")}"
    end
    provider.merge(
      url: url,
      enabled: provider[:enabled] && url.present?
    )
  end
end
