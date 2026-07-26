# frozen_string_literal: true

# Support providers for the Support LifePoints page.
# All options currently open the same Buy Me a Coffee page.
# Per-provider ENV vars can still override URLs later if needed.
module SupportProviders
  module_function

  BMC_URL = "https://buymeacoffee.com/lifepoints"

  PROVIDERS = [
    {
      id: :buy_me_a_coffee,
      kind: :primary,
      i18n_key: "support.providers.buy_me_a_coffee",
      url_env: "BUY_ME_A_COFFEE_URL",
      default_url: BMC_URL,
      enabled: true
    },
    {
      id: :become_supporter,
      kind: :secondary,
      i18n_key: "support.providers.become_supporter",
      url_env: "SUPPORT_SUPPORTER_URL",
      default_url: BMC_URL,
      enabled: true
    },
    {
      id: :sponsor_development,
      kind: :secondary,
      i18n_key: "support.providers.sponsor_development",
      url_env: "SUPPORT_SPONSOR_URL",
      default_url: BMC_URL,
      enabled: true
    },
    {
      id: :make_contribution,
      kind: :secondary,
      i18n_key: "support.providers.make_contribution",
      url_env: "SUPPORT_CONTRIBUTION_URL",
      default_url: BMC_URL,
      enabled: true
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
    provider.merge(
      url: url,
      enabled: provider[:enabled] && url.present?
    )
  end
end
