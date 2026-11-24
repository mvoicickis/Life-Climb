# frozen_string_literal: true

require "test_helper"

class FirstTipAcksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    @user.update!(support_milestones_shown: [])
  end

  test "create marks milestone and daily log" do
    post first_tip_ack_path, params: { key: "mountain" }, as: :json

    assert_response :no_content
    assert @user.reload.first_tip_seen?("mountain")
    assert_equal %w[mountain], Array(@user.first_tips_daily["keys"])
  end

  test "create is idempotent" do
    post first_tip_ack_path, params: { key: "circle" }, as: :json
    assert_response :no_content

    post first_tip_ack_path, params: { key: "circle" }, as: :json
    assert_response :no_content

    assert_equal 1, @user.reload.support_milestones_shown.count { |k| k == "first_tip_circle" }
  end

  test "unknown key returns 422" do
    post first_tip_ack_path, params: { key: "finish" }, as: :json

    assert_response :unprocessable_entity
    refute @user.reload.first_tip_seen?("finish")
  end

  test "impersonation blocks mutation" do
    admin = users(:admin)
    sign_in_as admin

    post admin_impersonations_path, params: { user_id: @user.id }
    assert_response :redirect

    post first_tip_ack_path, params: { key: "mountain" }, as: :json

    assert_response :forbidden
    refute @user.reload.first_tip_seen?("mountain")
  end
end