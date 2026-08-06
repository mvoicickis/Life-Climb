# frozen_string_literal: true

module Notifications
  # System cron entrypoint (GitHub Actions) — not per-user signed_id auth.
  class MorningNudgesController < ApplicationController
    allow_unauthenticated_access
    skip_forgery_protection
    skip_onboarding_check

    def create
      unless cron_authorized?
        return render json: { ok: false, error: "unauthorized" }, status: :unauthorized
      end

      result = MorningNudgeRun.call
      render json: {
        ok: true,
        considered: result.considered,
        sent: result.sent,
        skipped: result.skipped
      }
    end

    private

    def cron_authorized?
      expected = ENV["CRON_SECRET"].to_s
      return false if expected.blank?

      provided = bearer_token.presence || request.headers["X-Cron-Secret"].to_s
      return false if provided.blank?
      return false if expected.bytesize != provided.bytesize

      ActiveSupport::SecurityUtils.secure_compare(expected, provided)
    end

    def bearer_token
      header = request.authorization.to_s
      return if header.blank?

      scheme, token = header.split(" ", 2)
      return unless scheme&.casecmp("Bearer")&.zero?

      token.to_s
    end
  end
end
