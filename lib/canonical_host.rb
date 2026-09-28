# frozen_string_literal: true

module CanonicalHost
  CANONICAL_HOST = "lifeclimb.app"

  def self.base_url
    host = ENV["APP_HOST"].presence || CANONICAL_HOST
    "https://#{host}"
  end

  def self.absolute_url(path)
    "#{base_url}#{path}"
  end
end
