# frozen_string_literal: true

require "test_helper"

class DailyTodosFirstTipStreamTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      name: "Alex",
      email_address: "first-tip-stream-#{SecureRandom.hex(4)}@example.com",
      password: "password12345",
      password_confirmation: "password12345",
      onboarding_completed_at: Time.current
    )
    @result = Onboarding::Bootstrap.call(
      user: @user,
      goal_title: "Ship",
      camp_titles: [ "Launch" ],
      complete_onboarding: true,
      first_camp_reveal_status: "done"
    )
    @journey = @result.journey
    mark_onboarding_v3!(@journey)
    Onboarding::PlantBattles.call(
      user: @user,
      journey: @journey,
      battle_titles: [ "Battle one", "Battle two" ]
    )
    @zone = "Europe/Berlin"
    @user.create_notification_preference!(time_zone: @zone) unless @user.notification_preference
    @user.notification_preference.update!(time_zone: @zone)
    sign_in_as(@user)
    @todo = @user.daily_todos.where(completed_at: nil).order(:id).first
  end

  test "first win turbo stream replaces first-tip-host with mountain key" do
    post complete_daily_todo_path(@todo), as: :turbo_stream

    assert_response :ok
    assert_match %(action="replace" target="first-tip-host"), response.body
    assert_match 'data-first-tip-key-value="mountain"', response.body
    assert_match 'data-controller="first-tip"', response.body
  end

  test "win stream with streak moment still replaces first-tip-host with mountain key" do
    tz = Time.find_zone!(@zone)

    travel_to tz.local(2026, 8, 5, 12, 0, 0) do
      post complete_daily_todo_path(@todo), as: :turbo_stream
      assert_response :ok
    end

    travel_to tz.local(2026, 8, 6, 12, 0, 0) do
      todo2 = @user.daily_todos.where(completed_at: nil).order(:id).first
      assert todo2, "expected a second open battle"

      post complete_daily_todo_path(todo2), as: :turbo_stream

      assert_response :ok
      assert_match "data-controller=\"streak-moment\"", response.body
      assert_match %(action="replace" target="first-tip-host"), response.body
      assert_match 'data-first-tip-key-value="mountain"', response.body
    end
  end

  test "does not replace first-tip-host when next tip is nil" do
    @user.mark_first_tip_seen!("mountain")

    post complete_daily_todo_path(@todo), as: :turbo_stream

    assert_response :ok
    assert_no_match %(action="replace" target="first-tip-host"), response.body
  end

  test "uncomplete does not replace first-tip-host" do
    post complete_daily_todo_path(@todo), as: :turbo_stream
    assert_match "first-tip-host", response.body

    post complete_daily_todo_path(@todo), as: :turbo_stream

    assert_response :ok
    assert_no_match %(action="replace" target="first-tip-host"), response.body
  end

  private

  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: "password12345" }
  end

  def mark_onboarding_v3!(journey)
    flags = (journey.setup_flags.presence || {}).stringify_keys.merge(
      Onboarding::Bootstrap::ONBOARDING_V3_FLAG => "true"
    )
    journey.update_columns(setup_flags: flags, updated_at: Time.current)
  end
end
