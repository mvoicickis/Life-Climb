# frozen_string_literal: true

module Analytics
  # Persist a named product event for funnel and behavior analysis.
  class Track
    def self.call(user:, name:, properties: {})
      new(user:, name:, properties:).call
    end

    def initialize(user:, name:, properties: {})
      @user = user
      @name = name.to_s
      @properties = properties.stringify_keys
    end

    def call
      @user.user_events.create!(name: @name, properties: @properties)
    end
  end
end
