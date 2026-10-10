# frozen_string_literal: true

require "test_helper"

class NotificationTimeZonesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.notification_preference&.destroy
    sign_in_as @user
  end

  test "update sets time zone when missing" do
    patch notification_time_zone_path,
          params: { time_zone: "Europe/Berlin" },
          as: :json

    assert_response :no_content
    assert_equal "Europe/Berlin", @user.reload.notification_preference.time_zone
  end

  test "update does not overwrite existing time zone" do
    @user.create_notification_preference!(time_zone: "America/New_York")

    patch notification_time_zone_path,
          params: { time_zone: "Europe/Berlin" },
          as: :json

    assert_response :no_content
    assert_equal "America/New_York", @user.reload.notification_preference.time_zone
  end

  test "requires authentication" do
    sign_out
    patch notification_time_zone_path, params: { time_zone: "UTC" }, as: :json
    assert_response :redirect
  end
end
