# frozen_string_literal: true

module Play
  class AssetLinks
    RELATION = [ "delegate_permission/common.handle_all_urls" ].freeze

    def self.json
      package = ENV["PLAY_PACKAGE_NAME"].to_s.strip
      return [] if package.blank?

      fingerprints = fingerprints_from_env
      return [] if fingerprints.empty?

      [
        {
          "relation" => RELATION,
          "target" => {
            "namespace" => "android_app",
            "package_name" => package,
            "sha256_cert_fingerprints" => fingerprints
          }
        }
      ]
    end

    def self.fingerprints_from_env
      ENV.fetch("PLAY_SHA256_FINGERPRINTS", "")
        .split(",")
        .map(&:strip)
        .reject(&:blank?)
    end
    private_class_method :fingerprints_from_env
  end
end
