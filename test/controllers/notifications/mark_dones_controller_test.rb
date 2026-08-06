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
      refute body["created"]
      assert todo.reload.completed?
    end

    test "creates category example then marks done when none incomplete" do
      @user.daily_todos.for_day.update_all(completed_at: Time.current)
      @user.strategy_goals.where(horizon: "day", scheduled_on: Date.current).update_all(completed_at: Time.current)
      @user.daily_todos.for_day.incomplete.delete_all

      self_examples = Array(I18n.t("strategy.first_climb.examples.self.action"))
      career_examples = Array(I18n.t("strategy.first_climb.examples.career.action"))
      refute_equal self_examples.sort, career_examples.sort

      post notifications_mark_done_path,
           params: { token: @token, category: "self" },
           as: :json
      assert_response :success
      body = JSON.parse(response.body)
      assert body["ok"]
      assert body["created"]
      assert_includes self_examples, body["title"]
      assert @user.daily_todos.for_day.where(title: body["title"]).first.completed?
    end

    test "rejects invalid token" do
      post notifications_mark_done_path, params: { token: "bad" }, as: :json
      assert_response :unauthorized
    end
  end
end
