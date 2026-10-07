# frozen_string_literal: true

require "test_helper"

class BasicsLocalDayTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    seed_climb!(@user, today_mission: "Ship auth")
    dismiss_onboarding_missions!(@user)
    enable_habits!
    @journey = @user.primary_focused_journey
    @user.habits.destroy_all
    @binary = @user.habits.create!(
      name: "Meditate",
      unit: "times", points: 5, frequency: "daily",
      active: true, show_on_home: true, stat_type: "growth", quantity_checkin: false
    )
    @growth = @user.habits.create!(
      name: "Pages read", unit: "pages", points: 5, frequency: "daily",
      active: true, show_on_home: true, stat_type: "growth", goal: 10, quantity_checkin: true
    )
    @zone = "Europe/Berlin"
    @user.create_notification_preference!(time_zone: @zone)
  end

  test "binary tick at 00:30 Berlin uses Berlin date and updates basics count" do
    travel_to Time.find_zone!(@zone).local(2026, 8, 7, 0, 30, 0) do
      berlin_day = Date.new(2026, 8, 7)
      assert_equal berlin_day, @user.local_today
      assert_not_equal berlin_day, Date.current

      progress_before = Today::Commitment.progress(user: @user, journey: @journey, habits_on: berlin_day)

      post completions_path(habit_id: @binary.id)
      assert_redirected_to dashboard_path

      @binary.reload
      assert_equal berlin_day, @binary.completions.last.completed_on
      assert @binary.survived_today?(berlin_day)

      progress_after = Today::Commitment.progress(user: @user, journey: @journey.reload, habits_on: berlin_day)
      assert_equal progress_before.battle_done, progress_after.battle_done
      assert_equal progress_before.battle_required, progress_after.battle_required
      assert progress_after.habit_done >= 1

      get dashboard_path
      assert_response :success
      assert_select "#basics_survived_count", text: /1/
    end
  end

  test "quantity log at 00:30 Berlin uses Berlin date and awards rhythm once per local day" do
    travel_to Time.find_zone!(@zone).local(2026, 8, 7, 0, 30, 0) do
      berlin_day = Date.new(2026, 8, 7)
      rhythm_scope = -> { @user.life_point_ledgers.where(source: @growth) }

      assert_difference -> { rhythm_scope.call.count }, 1 do
        post daily_logs_path(habit_id: @growth.id),
          params: { mode: "set", daily_log: { amount: 10 } }
      end

      log = @growth.daily_logs.find_by!(logged_on: berlin_day)
      assert_equal berlin_day, log.logged_on

      assert_no_difference -> { rhythm_scope.call.count } do
        post daily_logs_path(habit_id: @growth.id),
          params: { mode: "add", daily_log: { amount: 2 } }
      end
    end
  end

  test "yesterday Berlin tick does not count for today at 23:30 Berlin" do
    travel_to Time.find_zone!(@zone).local(2026, 8, 7, 23, 30, 0) do
      berlin_today = Date.new(2026, 8, 7)
      @binary.completions.create!(user: @user, completed_on: berlin_today - 1, points_awarded: 5)

      refute @binary.survived_today?(berlin_today)

      get dashboard_path
      assert_response :success
      assert_select "#basics_survived_count", text: /0/
    end
  end

  test "no time zone uses UTC local today like battles" do
    @user.notification_preference&.destroy
    travel_to Time.zone.local(2026, 8, 7, 0, 30, 0) do
      assert_equal Date.current, @user.local_today

      post completions_path(habit_id: @binary.id)
      assert_equal Date.current, @binary.reload.completions.last.completed_on
      assert @binary.survived_today?(Date.current)
    end
  end

  test "open battle counts unchanged at 00:30 Berlin when ticking a basic" do
    travel_to Time.find_zone!(@zone).local(2026, 8, 7, 0, 30, 0) do
      berlin_day = Date.new(2026, 8, 7)
      get dashboard_path
      assert_response :success
      open_before = response.body[/data-battle-day-open-count-value="(\d+)"/, 1].to_i

      progress_before = Today::Commitment.progress(user: @user, journey: @journey, habits_on: berlin_day)

      post completions_path(habit_id: @binary.id)

      progress_after = Today::Commitment.progress(user: @user, journey: @journey.reload, habits_on: berlin_day)
      assert_equal progress_before.battle_done, progress_after.battle_done
      assert_equal progress_before.battle_required, progress_after.battle_required

      get dashboard_path
      assert_response :success
      open_after = response.body[/data-battle-day-open-count-value="(\d+)"/, 1].to_i
      assert_equal open_before, open_after
    end
  end
end
