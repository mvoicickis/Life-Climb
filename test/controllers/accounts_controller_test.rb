# frozen_string_literal: true

require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "destroy with correct password deletes user ends session and redirects to landing" do
    user_id = @user.id

    assert_difference "User.count", -1 do
      delete account_path, params: { password: "password12345" }
    end

    assert_redirected_to root_path
    assert_equal I18n.t("account_delete.deleted_notice"), flash[:notice]
    assert cookies[:session_id].blank?
    assert_not User.exists?(user_id)

    follow_redirect!
    assert_response :success

    get dashboard_path
    assert_redirected_to new_session_path
  end

  test "destroy with wrong password keeps user and shows error in sheet only" do
    delete account_path, params: { password: "wrong-password" }

    assert_redirected_to settings_path(delete_account: 1)
    assert_nil flash[:alert]
    assert User.exists?(@user.id)

    follow_redirect!
    assert_response :success
    assert_includes response.body, ERB::Util.html_escape(I18n.t("account_delete.errors.wrong_password"))
  end

  test "destroy requires sign in" do
    sign_out

    delete account_path, params: { password: "password12345" }

    assert_redirected_to new_session_path
    assert User.exists?(@user.id)
  end

  test "destroy blocked while impersonating" do
    admin = users(:admin)
    sign_in_as admin
    post admin_impersonations_path, params: { user_id: @user.id }

    delete account_path, params: { password: "password12345" }

    assert_redirected_to settings_path
    assert_equal I18n.t("account_delete.not_while_impersonating"), flash[:alert]
    assert User.exists?(@user.id)
  end

  test "destroy blocked when stripe cancel fails shows sheet error" do
    @user.update_columns(stripe_subscription_id: "sub_block", subscription_status: "active")

    with_singleton_stubs(
      Stripe::Subscription => {
        cancel: ->(*) { raise Stripe::APIError.new("down") }
      }
    ) do
      assert_no_difference "User.count" do
        delete account_path, params: { password: "password12345" }
      end
    end

    assert_redirected_to settings_path(delete_account: 1)
    follow_redirect!
    assert_includes response.body, ERB::Util.html_escape(I18n.t("account_delete.errors.stripe_blocked"))
    assert User.exists?(@user.id)
  end
end
