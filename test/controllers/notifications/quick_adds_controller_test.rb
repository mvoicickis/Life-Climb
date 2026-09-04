# frozen_string_literal: true

require "test_helper"

module Notifications
  class QuickAddsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      seed_climb!(@user, area_key: "career")
      @token = @user.signed_id(purpose: :notification_action, expires_in: 30.days)
    end

    test "creates battle with valid token" do
      career_examples = Array(I18n.t("strategy.first_climb.examples.career.action"))

      assert_difference -> { @user.daily_todos.for_day.count }, 1 do
        post notifications_quick_add_path,
             params: { token: @token, category: "career" },
             as: :json
      end

      assert_response :success
      body = JSON.parse(response.body)
      assert body["ok"]
      assert_includes career_examples, body["title"]
      assert_equal "career", body["category"]
      assert_equal @user.id, @user.daily_todos.for_day.order(:id).last.user_id
    end

    test "rejects invalid token" do
      post notifications_quick_add_path, params: { token: "not-valid" }, as: :json
      assert_response :unauthorized
      refute JSON.parse(response.body)["ok"]
    end

    test "does not create for another user token" do
      other = users(:two)
      seed_climb!(other, area_key: "self", title: "Other climb", today_mission: "Walk")
      other_token = other.signed_id(purpose: :notification_action, expires_in: 30.days)
      before = @user.daily_todos.for_day.count

      post notifications_quick_add_path, params: { token: other_token, category: "self" }, as: :json
      assert_response :success
      assert_equal before, @user.daily_todos.for_day.count
      assert_operator other.daily_todos.for_day.count, :>=, 1
    end

    test "battle_id surfaces existing battle on Today without creating a new goal" do
      journey = seed_climb!(@user, today_mission: "Ship login")
      battle = @user.strategy_goals.where(horizon: "day").order(:id).last
      @user.daily_todos.for_day.delete_all

      assert_no_difference -> { @user.strategy_goals.where(horizon: "day").count } do
        assert_difference -> { @user.daily_todos.for_day.count }, 1 do
          post notifications_quick_add_path,
               params: { token: @token, battle_id: battle.id },
               as: :json
        end
      end

      body = JSON.parse(response.body)
      assert body["ok"]
      assert_equal "Ship login", body["title"]
      assert_equal battle.id, @user.daily_todos.for_day.last.strategy_goal_id
      assert_equal journey.life_area_id, battle.life_area_id
    end

    test "rejects battle_id for another users battle" do
      other = users(:two)
      seed_climb!(other, area_key: "self", title: "Other climb", today_mission: "Walk")
      battle = other.strategy_goals.where(horizon: "day").order(:id).last

      post notifications_quick_add_path,
           params: { token: @token, battle_id: battle.id },
           as: :json

      assert_response :unprocessable_entity
      refute JSON.parse(response.body)["ok"]
    end
  end
end
