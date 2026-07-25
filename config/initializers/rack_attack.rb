# frozen_string_literal: true

class Rack::Attack
  # Use Rails.cache (memory_store in current prod; swap to Redis/Solid Cache when multi-dyno).
  Rack::Attack.cache.store = Rails.cache

  safelist("healthcheck") { |req| req.path == "/up" }

  # General abuse protection
  throttle("req/ip", limit: 300, period: 5.minutes) do |req|
    req.ip unless req.path.start_with?("/assets")
  end

  throttle("logins/ip", limit: 10, period: 3.minutes) do |req|
    req.ip if req.path == "/session" && req.post?
  end

  throttle("logins/email", limit: 8, period: 3.minutes) do |req|
    if req.path == "/session" && req.post?
      req.params.dig("email_address").to_s.downcase.presence
    end
  end

  throttle("registrations/ip", limit: 5, period: 15.minutes) do |req|
    req.ip if req.path == "/registration" && req.post?
  end

  throttle("password_resets/ip", limit: 5, period: 15.minutes) do |req|
    req.ip if req.path == "/passwords" && req.post?
  end

  throttle("password_update/ip", limit: 10, period: 15.minutes) do |req|
    req.ip if req.path.start_with?("/passwords/") && req.patch?
  end

  # Authenticated write bursts (spam / scripted abuse)
  throttle("writes/ip", limit: 120, period: 1.minute) do |req|
    req.ip if req.post? || req.patch? || req.put? || req.delete?
  end

  self.throttled_responder = lambda do |_request|
    [ 429, { "Content-Type" => "text/plain" }, [ "Too many requests. Please try again later.\n" ] ]
  end
end
