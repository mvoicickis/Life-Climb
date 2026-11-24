# frozen_string_literal: true

require "test_helper"

class FirstTipAcksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      name: "Alex",
      email_address: "first-tip-ack-#{SecureRandom.hex(4)}@example.com",
      password: "password12345",
      password_confirmation: "password12345"
    )
    Onboarding::Bootstrap.call(
      user: @user,
      goal_title: "Ship",
      camp_titles: [ "Launch" ]
    )
    @user.update!(support_milestones_shown: [])
    sign_in_as @user
  end

  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: "password12345" }
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
    post session_path, params: { email_address: admin.email_address, password: "password12345" }

    post admin_impersonations_path, params: { user_id: @user.id }
    assert_response :redirect

    post first_tip_ack_path, params: { key: "mountain" }, as: :json

    assert_response :forbidden
    refute @user.reload.first_tip_seen?("mountain")
  end
end
