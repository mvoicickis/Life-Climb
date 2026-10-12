# frozen_string_literal: true

require "test_helper"

module Play
  class AssetLinksControllerTest < ActionDispatch::IntegrationTest
    setup do
      @previous_package = ENV["PLAY_PACKAGE_NAME"]
      @previous_fingerprints = ENV["PLAY_SHA256_FINGERPRINTS"]
      ENV.delete("PLAY_PACKAGE_NAME")
      ENV.delete("PLAY_SHA256_FINGERPRINTS")
    end

    teardown do
      if @previous_package.nil?
        ENV.delete("PLAY_PACKAGE_NAME")
      else
        ENV["PLAY_PACKAGE_NAME"] = @previous_package
      end

      if @previous_fingerprints.nil?
        ENV.delete("PLAY_SHA256_FINGERPRINTS")
      else
        ENV["PLAY_SHA256_FINGERPRINTS"] = @previous_fingerprints
      end
    end

    test "returns empty array without env" do
      get play_asset_links_path

      assert_response :success
      assert_includes response.media_type, "application/json"
      assert_equal [], JSON.parse(response.body)
    end

    test "returns asset links when env is set" do
      ENV["PLAY_PACKAGE_NAME"] = "com.lifeclimb.app"
      ENV["PLAY_SHA256_FINGERPRINTS"] = "AA:BB:CC, DD:EE:FF"

      get play_asset_links_path

      assert_response :success
      body = JSON.parse(response.body)
      assert_equal 1, body.length
      assert_equal [ "delegate_permission/common.handle_all_urls" ], body[0]["relation"]
      target = body[0]["target"]
      assert_equal "android_app", target["namespace"]
      assert_equal "com.lifeclimb.app", target["package_name"]
      assert_equal [ "AA:BB:CC", "DD:EE:FF" ], target["sha256_cert_fingerprints"]
    end

    test "available during maintenance mode" do
      AppSetting.write(AppSetting::KEYS[:maintenance_mode], "true")

      get play_asset_links_path

      assert_response :success
      assert_equal [], JSON.parse(response.body)
    ensure
      AppSetting.write(AppSetting::KEYS[:maintenance_mode], "false")
    end
  end
end
