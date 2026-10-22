# frozen_string_literal: true

require "test_helper"

class TrustedProxiesRackAttackTest < ActiveSupport::TestCase
  CLOUDFLARE_EDGE = "172.69.1.1"
  CLIENT_A = "203.0.113.7"
  CLIENT_B = "203.0.113.8"
  UNTRUSTED_PEER = "198.51.100.99"

  setup do
    @original_trusted_proxies = Rails.application.config.action_dispatch.trusted_proxies
    Rails.application.config.action_dispatch.trusted_proxies = trusted_proxies
    @original_attack_cache = Rack::Attack.cache.store
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rails.application.config.action_dispatch.trusted_proxies = @original_trusted_proxies
    Rack::Attack.cache.store = @original_attack_cache
  end

  test "remote_ip uses client from X-Forwarded-For when peer is a Cloudflare address" do
    env = base_env(remote_addr: CLOUDFLARE_EDGE, x_forwarded_for: CLIENT_A)
    apply_remote_ip!(env)

    assert_equal CLIENT_A, ActionDispatch::Request.new(env).remote_ip
  end

  test "remote_ip ignores forged X-Forwarded-For from a non-Cloudflare peer" do
    env = base_env(remote_addr: UNTRUSTED_PEER, x_forwarded_for: CLIENT_A)
    apply_remote_ip!(env)

    assert_equal UNTRUSTED_PEER, ActionDispatch::Request.new(env).remote_ip
  end

  test "rack attack login throttle buckets clients not Cloudflare edges" do
    login_throttle = Rack::Attack.throttles["logins/ip"]

    10.times do |i|
      req = rack_attack_request(
        remote_addr: CLOUDFLARE_EDGE,
        x_forwarded_for: "203.0.113.#{i + 1}"
      )
      assert_not login_throttle.matched_by?(req), "expected client #{i + 1} to stay under the login limit"
    end

    10.times do
      req = rack_attack_request(remote_addr: CLOUDFLARE_EDGE, x_forwarded_for: CLIENT_A)
      login_throttle.matched_by?(req)
    end

    eleventh = rack_attack_request(remote_addr: CLOUDFLARE_EDGE, x_forwarded_for: CLIENT_A)
    assert login_throttle.matched_by?(eleventh)

    other_client = rack_attack_request(remote_addr: CLOUDFLARE_EDGE, x_forwarded_for: CLIENT_B)
    assert_not login_throttle.matched_by?(other_client)
  end

  private

  def trusted_proxies
    ActionDispatch::RemoteIp::TRUSTED_PROXIES + CLOUDFLARE_TRUSTED_PROXY_IPADDRS
  end

  def apply_remote_ip!(env)
    ActionDispatch::RemoteIp.new(->(e) { [ 200, {}, [] ] }, true, trusted_proxies).call(env)
  end

  def base_env(remote_addr:, x_forwarded_for:)
    {
      "REMOTE_ADDR" => remote_addr,
      "HTTP_X_FORWARDED_FOR" => x_forwarded_for,
      "REQUEST_METHOD" => "GET",
      "PATH_INFO" => "/",
      "rack.input" => StringIO.new
    }
  end

  def rack_attack_request(remote_addr:, x_forwarded_for:)
    env = base_env(remote_addr: remote_addr, x_forwarded_for: x_forwarded_for).merge(
      "REQUEST_METHOD" => "POST",
      "PATH_INFO" => "/session",
      "rack.input" => StringIO.new("email_address=throttle-test@example.com"),
      "CONTENT_TYPE" => "application/x-www-form-urlencoded",
      "CONTENT_LENGTH" => "36"
    )
    apply_remote_ip!(env)
    Rack::Attack::Request.new(env)
  end
end
