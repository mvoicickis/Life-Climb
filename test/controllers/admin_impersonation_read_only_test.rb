# frozen_string_literal: true

require "test_helper"

class AdminImpersonationReadOnlyTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @user = users(:one)
    seed_climb!(@user)
    dismiss_onboarding_missions!(@user)
    @journey = @user.reload.primary_focused_journey
    @todo = @user.daily_todos.for_day.first
  end

  test "GET dashboard while impersonating does not cascade daily todos" do
    @user.daily_todos.for_day.delete_all
    assert_equal 0, @user.daily_todos.for_day.count

    start_impersonating!(@admin, @user)

    assert_no_difference -> { @user.daily_todos.for_day.count } do
      get dashboard_path
    end
    assert_response :success
  end

  test "GET dashboard while impersonating does not touch session updated_at" do
    start_impersonating!(@admin, @user)
    session_record = @user.sessions.order(:id).last
    assert session_record

    travel 2.hours do
      old_updated = session_record.updated_at
      get dashboard_path
      assert_equal old_updated.to_i, session_record.reload.updated_at.to_i
    end
  end

  test "GET dashboard while impersonating does not reconcile climb streak" do
    @user.update!(climb_streak_days: 5, climb_streak_on: Date.current - 3)
    start_impersonating!(@admin, @user)

    get dashboard_path

    @user.reload
    assert_equal 5, @user.climb_streak_days
    assert_equal Date.current - 3, @user.climb_streak_on
  end

  test "mutating actions are blocked while impersonating" do
    start_impersonating!(@admin, @user)

    post complete_daily_todo_path(@todo)

    assert_redirected_to dashboard_path
    assert_match(/disabled while impersonating/i, flash[:alert].to_s)
    assert_not @todo.reload.completed?
  end

  test "locale can change for preview without persisting to user record" do
    @user.update!(locale: "en")
    start_impersonating!(@admin, @user)

    patch locale_path, params: { locale: "lv" }

    assert_redirected_to dashboard_path
    assert_equal "lv", session[:locale].to_s
    assert_equal "en", @user.reload.locale
  end

  test "impersonation banner shows read-only label" do
    start_impersonating!(@admin, @user)

    get dashboard_path

    assert_match(/Read-only/i, response.body)
  end

  test "admin can stop impersonating" do
    start_impersonating!(@admin, @user)

    delete admin_impersonation_path(@admin)

    assert_redirected_to admin_root_path
    assert_nil session[:admin_impersonator_id]
  end

  private

  def start_impersonating!(admin, target)
    sign_in_as admin
    post admin_impersonations_path, params: { user_id: target.id }
    follow_redirect!
  end
end
