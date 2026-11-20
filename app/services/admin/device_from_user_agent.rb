# frozen_string_literal: true

module Admin
  # Map a browser user agent string to a coarse device bucket for admin triage.
  class DeviceFromUserAgent
    DEVICE_ANDROID = :android
    DEVICE_IPHONE = :iphone
    DEVICE_COMPUTER = :computer

    ANDROID_PATTERN = /Android/i
    APPLE_MOBILE_PATTERN = /iPad|iPhone|iPod/i

    def self.call(user_agent)
      new(user_agent).call
    end

    def initialize(user_agent)
      @user_agent = user_agent.to_s
    end

    def call
      return nil if @user_agent.blank?

      return DEVICE_ANDROID if @user_agent.match?(ANDROID_PATTERN)
      return DEVICE_IPHONE if @user_agent.match?(APPLE_MOBILE_PATTERN)

      DEVICE_COMPUTER
    end
  end
end
