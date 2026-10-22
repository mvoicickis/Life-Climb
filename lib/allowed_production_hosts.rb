# frozen_string_literal: true

module AllowedProductionHosts
  CANONICAL_HOST = "lifeclimb.app"
  WWW_CANONICAL_HOST = "www.lifeclimb.app"
  ONRENDER_REGEX = /.*\.onrender\.com/

  def self.call(env)
    hosts = []
    hosts << env["APP_HOST"] if env["APP_HOST"].present?
    hosts << env["RENDER_EXTERNAL_HOSTNAME"] if env["RENDER_EXTERNAL_HOSTNAME"].present?
    hosts << CANONICAL_HOST
    hosts << WWW_CANONICAL_HOST
    unless env["APP_HOST"].present? || env["RENDER_EXTERNAL_HOSTNAME"].present?
      hosts << ONRENDER_REGEX
    end
    hosts.uniq
  end
end
