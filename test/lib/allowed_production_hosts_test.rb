# frozen_string_literal: true

require "test_helper"

class AllowedProductionHostsTest < ActiveSupport::TestCase
  test "APP_HOST and RENDER_EXTERNAL_HOSTNAME both allowed with canonical hosts, no regex" do
    hosts = AllowedProductionHosts.call(
      "APP_HOST" => "lifeclimb.app",
      "RENDER_EXTERNAL_HOSTNAME" => "lifepoints.onrender.com"
    )

    assert_includes hosts, "lifeclimb.app"
    assert_includes hosts, "www.lifeclimb.app"
    assert_includes hosts, "lifepoints.onrender.com"
    assert_equal 3, hosts.size
    assert_not hosts.any?(Regexp)
  end

  test "duplicate APP_HOST and RENDER_EXTERNAL_HOSTNAME are deduplicated" do
    hosts = AllowedProductionHosts.call(
      "APP_HOST" => "lifepoints.onrender.com",
      "RENDER_EXTERNAL_HOSTNAME" => "lifepoints.onrender.com"
    )

    assert_includes hosts, "lifepoints.onrender.com"
    assert_includes hosts, "lifeclimb.app"
    assert_includes hosts, "www.lifeclimb.app"
    assert_equal 3, hosts.size
  end

  test "neither APP_HOST nor RENDER_EXTERNAL_HOSTNAME includes onrender regex" do
    hosts = AllowedProductionHosts.call({})

    assert_includes hosts, AllowedProductionHosts::ONRENDER_REGEX
    assert_includes hosts, "lifeclimb.app"
    assert_includes hosts, "www.lifeclimb.app"
  end
end
