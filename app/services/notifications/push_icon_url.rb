# frozen_string_literal: true

module Notifications
  # Absolute PNG URL for Web Push notification icons (Android rejects WebP).
  class PushIconUrl
    def self.for(user:)
      new(user: user).call
    end

    def initialize(user:)
      @user = user
    end

    def call
      asset = @user.avatar_push_image
      return nil if asset.blank?

      path = ActionController::Base.helpers.asset_path(asset)
      path = "/#{path}" unless path.start_with?("/")
      PushAssetUrl.call(path)
    end
  end
end