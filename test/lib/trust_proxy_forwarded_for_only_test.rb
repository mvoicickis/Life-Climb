# frozen_string_literal: true

require "test_helper"

class TrustProxyForwardedForOnlyTest < ActiveSupport::TestCase
  test "calculate_ip falls back to super when proxies are not enumerable" do
    env = {
      "REMOTE_ADDR" => "203.0.113.1",
      "REQUEST_METHOD" => "GET",
      "PATH_INFO" => "/",
      "rack.input" => StringIO.new
    }
    req = ActionDispatch::Request.new(env)
    get_ip = ActionDispatch::RemoteIp::GetIp.new(req, true, ActionDispatch::RemoteIp::TRUSTED_PROXIES)
    get_ip.instance_variable_set(:@proxies, Object.new)
    # Web Console’s GetSecureIp overrides filter_proxies; stand in so super can finish.
    get_ip.define_singleton_method(:filter_proxies) { |ips| ips }

    ip = nil
    assert_nothing_raised { ip = get_ip.send(:calculate_ip) }
    assert_equal "203.0.113.1", ip
  end
end
