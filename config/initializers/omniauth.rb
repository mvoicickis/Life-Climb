# frozen_string_literal: true

OmniAuth.config.allowed_request_methods = [ :post ]
OmniAuth.config.silence_get_warning = true

OmniAuth.config.full_host = lambda do |env|
  request = Rack::Request.new(env)
  "#{request.scheme}://#{request.host_with_port}"
end

Rails.application.config.middleware.use OmniAuth::Builder do
  client_id = ENV["GOOGLE_CLIENT_ID"].to_s.strip.presence
  client_secret = ENV["GOOGLE_CLIENT_SECRET"].to_s.strip.presence

  if client_id.present? && client_secret.present?
    provider :google_oauth2,
      client_id,
      client_secret,
      scope: "openid email profile",
      prompt: "select_account",
      name: "google_oauth2"
  elsif Rails.env.test?
    provider :google_oauth2,
      "test-google-client-id",
      "test-google-client-secret",
      scope: "openid email profile",
      prompt: "select_account",
      name: "google_oauth2"
  else
    Rails.logger.warn(
      "[omniauth] GOOGLE_CLIENT_ID / GOOGLE_CLIENT_SECRET missing — Google sign-in disabled"
    )
  end
end
