# frozen_string_literal: true

module Notifications
  class PushAssetUrl
    def self.call(path)
      CanonicalHost.absolute_url(path)
    end
  end
end
