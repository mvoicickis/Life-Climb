# frozen_string_literal: true

# Cloudflare anycast ranges (snapshot 2026-10-22).
# Sources: https://www.cloudflare.com/ips-v4 and https://www.cloudflare.com/ips-v6
CLOUDFLARE_TRUSTED_PROXY_CIDRS = [
  "173.245.48.0/20",
  "103.21.244.0/22",
  "103.22.200.0/22",
  "103.31.4.0/22",
  "141.101.64.0/18",
  "108.162.192.0/18",
  "190.93.240.0/20",
  "188.114.96.0/20",
  "197.234.240.0/22",
  "198.41.128.0/17",
  "162.158.0.0/15",
  "104.16.0.0/13",
  "104.24.0.0/14",
  "172.64.0.0/13",
  "131.0.72.0/22",
  "2400:cb00::/32",
  "2606:4700::/32",
  "2803:f800::/32",
  "2405:b500::/32",
  "2405:8100::/32",
  "2a06:98c0::/29",
  "2c0f:f248::/32"
].freeze

CLOUDFLARE_TRUSTED_PROXY_IPADDRS = CLOUDFLARE_TRUSTED_PROXY_CIDRS.map { |cidr| IPAddr.new(cidr) }.freeze

# Only trust X-Forwarded-For when the TCP peer is a configured proxy (e.g. Cloudflare).
# Direct hits to Render with a forged header keep REMOTE_ADDR as the client IP.
module TrustProxyForwardedForOnly
  private

  def calculate_ip
    remote_addr = sanitize_ips(ips_from(@req.remote_addr)).last
    peer_is_trusted_proxy = @proxies.any? { |proxy| proxy === remote_addr }
    return remote_addr unless peer_is_trusted_proxy

    super
  end
end

ActionDispatch::RemoteIp::GetIp.prepend(TrustProxyForwardedForOnly)

if Rails.env.production?
  Rails.application.config.action_dispatch.trusted_proxies =
    ActionDispatch::RemoteIp::TRUSTED_PROXIES + CLOUDFLARE_TRUSTED_PROXY_IPADDRS
end
