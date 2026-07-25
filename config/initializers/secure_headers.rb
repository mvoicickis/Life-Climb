# frozen_string_literal: true

Rails.application.config.action_dispatch.default_headers.merge!(
  "X-Frame-Options" => "DENY",
  "X-Content-Type-Options" => "nosniff",
  "Referrer-Policy" => "strict-origin-when-cross-origin",
  "Permissions-Policy" => "camera=(), microphone=(), geolocation=(), payment=()",
  "X-Permitted-Cross-Domain-Policies" => "none"
)
