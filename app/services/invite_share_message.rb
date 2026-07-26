# frozen_string_literal: true

# Product invite copy for Support / Settings share sheet (no habit required).
class InviteShareMessage
  def self.body(landing_url: nil)
    new(landing_url: landing_url).body
  end

  def self.call(landing_url:)
    new(landing_url: landing_url).call
  end

  def initialize(landing_url:)
    @landing_url = landing_url
  end

  def call
    [ body, "", I18n.t("share.try_it"), @landing_url ].join("\n")
  end

  def body
    [ I18n.t("share.invite.body"), "", I18n.t("share.invite.closer") ].join("\n")
  end
end
