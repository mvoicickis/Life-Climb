# frozen_string_literal: true

require "test_helper"

class AdminPanelTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @user = users(:one)
    @other = users(:two)
  end

  test "non admin is redirected from admin dashboard with access denied" do
    sign_in_as @user
    get admin_root_path
    assert_redirected_to dashboard_path
    follow_redirect!
    assert_match(/Access denied/i, flash[:alert].to_s + response.body)
  end

  test "guest is sent to sign in for admin" do
    get admin_root_path
    assert_redirected_to new_session_path
  end

  test "admin can open dashboard users statistics system feedback and ops" do
    sign_in_as @admin

    get admin_root_path
    assert_response :success
    assert_match(/Total users/i, response.body)

    get admin_users_path
    assert_response :success
    assert_match(@user.email_address, response.body)

    get admin_statistics_path
    assert_response :success

    get admin_system_path
    assert_response :success
    assert_match(/Rails/i, response.body)

    get admin_feedbacks_path
    assert_response :success

    get admin_ops_path
    assert_response :success
  end

  test "admin can search and sort users" do
    sign_in_as @admin
    get admin_users_path, params: { q: @user.email_address, sort: "points" }
    assert_response :success
    assert_match(@user.email_address, response.body)
    assert_no_match(@other.email_address, response.body)
  end

  test "admin can view edit promote demote and export users" do
    sign_in_as @admin

    get admin_user_path(@user)
    assert_response :success

    get edit_admin_user_path(@user)
    assert_response :success

    patch admin_user_path(@user), params: { user: { name: "Updated One" } }
    assert_redirected_to admin_user_path(@user)
    assert_equal "Updated One", @user.reload.name

    patch promote_admin_user_path(@user)
    assert @user.reload.admin?

    patch demote_admin_user_path(@user)
    assert_not @user.reload.admin?

    get admin_users_path(format: :csv)
    assert_response :success
    assert_includes response.body, "email"
    assert_includes response.body, @user.email_address
  end

  test "admin cannot demote or delete self" do
    sign_in_as @admin

    patch demote_admin_user_path(@admin)
    assert @admin.reload.admin?

    assert_no_difference "User.count" do
      delete admin_user_path(@admin)
    end
  end

  test "admin can delete another user" do
    sign_in_as @admin
    assert_difference "User.count", -1 do
      delete admin_user_path(@other)
    end
    assert_redirected_to admin_users_path
  end

  test "non admin cannot promote via direct url" do
    sign_in_as @user
    patch promote_admin_user_path(@other)
    assert_redirected_to dashboard_path
    assert_not @other.reload.admin?
  end

  test "admin can impersonate and return" do
    sign_in_as @admin

    post admin_impersonations_path, params: { user_id: @user.id }
    assert_redirected_to dashboard_path
    assert_equal @admin.id, session[:admin_impersonator_id]

    delete admin_impersonation_path(@admin)
    assert_redirected_to admin_root_path
    assert_nil session[:admin_impersonator_id]
  end

  test "admin can update ops settings and export statistics" do
    sign_in_as @admin

    patch admin_ops_path, params: {
      maintenance_mode: "1",
      announcement_banner: "Climb carefully today.",
      feature_feedback_inbox: "1",
      feature_export_stats: "1"
    }
    assert_redirected_to admin_ops_path
    assert AppSetting.maintenance_mode?
    assert_equal "Climb carefully today.", AppSetting.announcement_banner

    get admin_statistics_path(format: :csv)
    assert_response :success
    assert_includes response.body, "users_total"
  end

  test "maintenance mode blocks non admins but not admins" do
    AppSetting.write(AppSetting::KEYS[:maintenance_mode], "true")

    sign_in_as @user
    get dashboard_path
    assert_response :service_unavailable
    assert_match(/maintenance/i, response.body)

    sign_out
    sign_in_as @admin
    get admin_root_path
    assert_response :success
  ensure
    AppSetting.write(AppSetting::KEYS[:maintenance_mode], "false")
  end

  test "admin nav link is hidden from normal users" do
    sign_in_as @user
    get settings_path
    assert_response :success
    assert_no_match(%r{href=["']/admin["']}, response.body)
  end

  test "admin nav link is visible to admins" do
    sign_in_as @admin
    get settings_path
    assert_response :success
    assert_match(%r{href=["']/admin["']}, response.body)
  end
end
