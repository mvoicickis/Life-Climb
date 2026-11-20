# frozen_string_literal: true

require "test_helper"

module Admin
  class DeviceFromUserAgentTest < ActiveSupport::TestCase
    CHROME_ANDROID =
      "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) " \
      "Chrome/120.0.0.0 Mobile Safari/537.36"
    ECOSIA_ANDROID =
      "Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) " \
      "Chrome/120.0.0.0 Mobile Safari/537.36 Ecosiaandroid/6.0.1"
    SAMSUNG_INTERNET =
      "Mozilla/5.0 (Linux; Android 13; SAMSUNG SM-G991B) AppleWebKit/537.36 (KHTML, like Gecko) " \
      "SamsungBrowser/23.0 Chrome/115.0.0.0 Mobile Safari/537.36"
    IPHONE_SAFARI =
      "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) " \
      "Version/17.0 Mobile/15E148 Safari/604.1"
    IPAD =
      "Mozilla/5.0 (iPad; CPU OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) " \
      "Version/17.0 Mobile/15E148 Safari/604.1"
    WINDOWS_CHROME =
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) " \
      "Chrome/120.0.0.0 Safari/537.36"
    MAC_SAFARI =
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) " \
      "Version/17.0 Safari/605.1.15"
    LINUX_FIREFOX =
      "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:120.0) Gecko/20100101 Firefox/120.0"

    test "maps common mobile and desktop user agents" do
      assert_equal DeviceFromUserAgent::DEVICE_ANDROID, DeviceFromUserAgent.call(CHROME_ANDROID)
      assert_equal DeviceFromUserAgent::DEVICE_ANDROID, DeviceFromUserAgent.call(ECOSIA_ANDROID)
      assert_equal DeviceFromUserAgent::DEVICE_ANDROID, DeviceFromUserAgent.call(SAMSUNG_INTERNET)
      assert_equal DeviceFromUserAgent::DEVICE_IPHONE, DeviceFromUserAgent.call(IPHONE_SAFARI)
      assert_equal DeviceFromUserAgent::DEVICE_IPHONE, DeviceFromUserAgent.call(IPAD)
      assert_equal DeviceFromUserAgent::DEVICE_COMPUTER, DeviceFromUserAgent.call(WINDOWS_CHROME)
      assert_equal DeviceFromUserAgent::DEVICE_COMPUTER, DeviceFromUserAgent.call(MAC_SAFARI)
      assert_equal DeviceFromUserAgent::DEVICE_COMPUTER, DeviceFromUserAgent.call(LINUX_FIREFOX)
    end

    test "blank user agent returns nil" do
      assert_nil DeviceFromUserAgent.call(nil)
      assert_nil DeviceFromUserAgent.call("")
      assert_nil DeviceFromUserAgent.call("   ")
    end
  end
end