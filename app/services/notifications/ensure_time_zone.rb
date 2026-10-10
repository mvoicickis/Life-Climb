# frozen_string_literal: true

module Notifications
  # Set notification_preference.time_zone from browser IANA id — only when blank.
  class EnsureTimeZone
    def self.call(user:, zone:)
      new(user:, zone:).call
    end

    def initialize(user:, zone:)
      @user = user
      @zone = zone.to_s.strip
    end

    def call
      return false if @zone.blank?
      return false unless valid_iana_time_zone?(@zone)

      pref = @user.notification_preference || @user.create_notification_preference!
      return false if pref.time_zone.present?

      pref.update!(time_zone: @zone)
      true
    end

    private

    def valid_iana_time_zone?(zone)
      TZInfo::Timezone.get(zone)
      true
    rescue TZInfo::InvalidTimezoneIdentifier
      false
    end
  end
end
