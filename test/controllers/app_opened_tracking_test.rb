# frozen_string_literal: true

require "test_helper"

class AppOpenedTrackingTest < ActionDispatch::IntegrationTest
  ZONE = "Europe/Berlin"

  setup do
    @user = users(:one)
    @user.update!(character: "fox", planning_version: 2, onboarding_completed_at: Time.current)
    @user.create_notification_preference!(time_zone: ZONE)
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Find a job",
      ideal_scene: "Hired",
      current_reality: "Searching",
      today_mission: "Plan the path",
      closer_percent: 10,
      route_mission: true
    )
    @journey = @user.reload.primary_focused_journey
    sign_in_as @user
  end

  test "first Today GET of the local day records one app_opened event" do
    travel_to berlin_time(2026, 10, 16, 10, 0) do
      assert_difference -> { app_opened_events.count }, 1 do
        get dashboard_path
      end
      assert_response :success

      event = app_opened_events.last
      assert_equal "app_opened", event.name
      assert_equal "2026-10-16", event.properties["local_date"]
      assert_equal ZONE, event.properties["time_zone"]
      assert_equal Date.new(2026, 10, 16), @user.reload.last_opened_on
      assert @user.next_app_open_at.present?
    end
  end

  test "second Today or Mountain GET the same local day records no new event" do
    travel_to berlin_time(2026, 10, 16, 10, 0) do
      get dashboard_path
      assert_response :success

      assert_no_difference -> { app_opened_events.count } do
        get dashboard_path
        get life_journey_path(@journey)
      end
      assert_response :success
    end
  end

  test "next local day records one new app_opened event" do
    travel_to berlin_time(2026, 10, 16, 23, 0) do
      get dashboard_path
      assert_equal 1, app_opened_events.count
    end

    travel_to berlin_time(2026, 10, 17, 8, 0) do
      assert_difference -> { app_opened_events.count }, 1 do
        get dashboard_path
      end

      event = app_opened_events.last
      assert_equal "2026-10-17", event.properties["local_date"]
    end
  end

  test "impersonated GET does not record app_opened" do
    admin = users(:admin)
    sign_in_as admin
    post admin_impersonations_path, params: { user_id: @user.id }
    follow_redirect!

    travel_to berlin_time(2026, 10, 16, 10, 0) do
      assert_no_difference -> { app_opened_events.count } do
        get dashboard_path
      end
      assert_response :success
    end
  end

  test "Turbo Stream GET does not record app_opened" do
    travel_to berlin_time(2026, 10, 16, 10, 0) do
      assert_no_difference -> { app_opened_events.count } do
        get dashboard_path, as: :turbo_stream
      end
    end
  end

  test "prefetch GET does not record app_opened" do
    travel_to berlin_time(2026, 10, 16, 10, 0) do
      assert_no_difference -> { app_opened_events.count } do
        get dashboard_path, headers: { "X-Sec-Purpose" => "prefetch" }
      end
      assert_response :success
    end
  end

  test "tracker failure does not break Today GET" do
    travel_to berlin_time(2026, 10, 16, 10, 0) do
      Analytics::TrackAppOpened.stub(:call, proc { raise StandardError, "boom" }) do
        assert_no_difference -> { app_opened_events.count } do
          get dashboard_path
        end
        assert_response :success
      end
    end
  end

  test "service records only one event when called twice the same local day" do
    travel_to berlin_time(2026, 10, 16, 12, 0) do
      assert Analytics::TrackAppOpened.call(user: @user)
      refute Analytics::TrackAppOpened.call(user: @user.reload)
      assert_equal 1, app_opened_events.count
      assert_equal Date.new(2026, 10, 16), @user.reload.last_opened_on
    end
  end

  private

  def app_opened_events
    @user.user_events.named("app_opened")
  end

  def berlin_time(year, month, day, hour, minute)
    Time.find_zone!(ZONE).local(year, month, day, hour, minute, 0)
  end
end
