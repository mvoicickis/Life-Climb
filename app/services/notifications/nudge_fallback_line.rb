# frozen_string_literal: true

module Notifications
  # Rotating fallback copy when there is no open battle and no streak commitment.
  class NudgeFallbackLine
    I18N_ROOTS = {
      morning: "notifications.morning_push.lines",
      evening: "notifications.evening_push.lines"
    }.freeze

    def self.for(user:, date:, kind:, locale: I18n.locale)
      new(user: user, date: date, kind: kind, locale: locale).call
    end

    def initialize(user:, date:, kind:, locale: I18n.locale)
      @user = user
      @date = date
      @kind = kind.to_sym
      @locale = locale
    end

    def call
      I18n.with_locale(@locale) do
        lines = I18n.t(I18N_ROOTS.fetch(@kind))
        raise ArgumentError, "missing nudge lines for #{@kind}" unless lines.is_a?(Array) && lines.any?

        index = (@user.id + @date.jd) % lines.size
        lines.fetch(index)
      end
    end
  end
end
