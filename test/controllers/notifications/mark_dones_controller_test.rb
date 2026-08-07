# frozen_string_literal: true

require "test_helper"

module Notifications
  class MarkDonesControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      seed_climb!(@user, area_key: "self", today_mission: "Stretch")
      @token = @user.signed_id(purpose: :notification_action, expires_in: 30.days)
    end

    test "marks existing battle done" do
      todo = @user.daily_todos.for_day.incomplete.first
      assert todo

      post notifications_mark_done_path, params: { token: @token }, as: :json
      assert_response :success
      body = JSON.parse(response.body)
      assert body["ok"]
      refute body["nothing_to_mark"]
      assert todo.reload.completed?
    end

    test "returns honest nothing_to_mark when no incomplete battle" do
      @user.daily_todos.for_day.update_all(completed_at: Time.current)
      @user.strategy_goals.where(horizon: "day", scheduled_on: Date.current).update_all(completed_at: Time.current)
      @user.daily_todos.for_day.incomplete.delete_all
      before_count = @user.daily_todos.for_day.count

      post notifications_mark_done_path,
           params: { token: @token, category: "self" },
           as: :json
      assert_response :success
      body = JSON.parse(response.body)
      assert body["ok"]
      assert body["nothing_to_mark"]
      assert_equal I18n.t("notifications.actions.mark_done_none"), body["message"]
      assert_equal before_count, @user.daily_todos.for_day.count
      assert @user.daily_todos.for_day.incomplete.none?
    end

    test "rejects invalid token" do
      post notifications_mark_done_path, params: { token: "bad" }, as: :json
      assert_response :unauthorized
    end
  end
end
