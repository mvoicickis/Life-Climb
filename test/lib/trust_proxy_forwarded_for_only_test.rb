# frozen_string_literal: true

require "test_helper"

class TrustProxyForwardedForOnlyTest < ActiveSupport::TestCase
  # Web Console passes a Permissions object instead of an enumerable proxy list.
  class NonEnumerableProxies
  end

  test "remote_ip middleware does not call any? when proxies are not enumerable" do
    env = {
      "REMOTE_ADDR" => "203.0.113.1",
      "REQUEST_METHOD" => "GET",
      "PATH_INFO" => "/",
      "rack.input" => StringIO.new
    }

    assert_nothing_raised do
      ActionDispatch::RemoteIp.new(->(e) { [ 200, {}, [] ] }, true, NonEnumerableProxies.new).call(env)
    end

    assert_equal "203.0.113.1", env["action_dispatch.remote_ip"]
  end
end
