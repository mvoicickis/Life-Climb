# frozen_string_literal: true

require "test_helper"

module Notifications
  class SnoozesControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      @token = @user.signed_id(purpose: :notification_action, expires_in: 30.days)
      @user.daily_todos.delete_all
      @user.notification_preference&.destroy
    end

    test "sets snoozed_until about four hours ahead" do
      freeze_time do
        assert_difference -> { @user.daily_todos.count }, 0 do
          post notifications_snooze_path, params: { token: @token }, as: :json
        end
      end

      assert_response :success
      body = JSON.parse(response.body)
      assert body["ok"]
      pref = @user.reload.notification_preference
      assert pref.snoozed?
      assert_in_delta 4.hours.from_now, pref.snoozed_until, 2.seconds
      assert_equal 0, @user.strategy_goals.where(horizon: "day", scheduled_on: Date.current).count
    end

    test "rejects invalid token" do
      post notifications_snooze_path, params: { token: "bad" }, as: :json
      assert_response :unauthorized
    end
  end
end
