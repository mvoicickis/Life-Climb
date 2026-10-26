# frozen_string_literal: true

require "test_helper"

class StreakCommitmentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.daily_todos.delete_all
    sign_in_as @user
    @zone = "Europe/Berlin"
    @user.create_notification_preference!(time_zone: @zone) unless @user.notification_preference
    @user.notification_preference.update!(time_zone: @zone)
    @user.update!(
      last_streak_moment_on: nil,
      streak_commitment_target_days: nil,
      streak_commitment_started_on: nil,
      streak_commit_declines: 0,
      push_offer_permission_denied_at: nil,
      push_offer_dismiss_count: 0,
      push_offer_dismissed_at: nil,
      push_offer_show_days: 0,
      push_offer_last_shown_on: nil
    )
    @today = Date.new(2026, 8, 6)
  end

  test "create commits target and returns reminder html when push not denied" do
    travel_to Time.find_zone!(@zone).local(2026, 8, 6, 12, 0, 0) do
      seed_two_day_streak!

      post streak_commitment_path, params: { days: 7 }, as: :json
      assert_response :success
      body = JSON.parse(response.body)
      assert body["ok"]
      assert_includes body["html"], "lp-streak-moment__card is-reminder"
      assert_includes body["html"], "data-push-offer-source-value=\"streak\""

      @user.reload
      assert_equal 7, @user.streak_commitment_target_days
      assert_equal @today, @user.streak_commitment_started_on
    end
  end

  test "create skips reminder html when push permission denied" do
    travel_to Time.find_zone!(@zone).local(2026, 8, 6, 12, 0, 0) do
      seed_two_day_streak!
      @user.update!(push_offer_permission_denied_at: Time.current)

      post streak_commitment_path, params: { days: 7 }, as: :json
      assert_response :success
      body = JSON.parse(response.body)
      assert body["ok"]
      assert_equal "", body["html"]
      assert_equal 7, @user.reload.streak_commitment_target_days
    end
  end

  test "create rejects target not ahead of streak" do
    travel_to Time.find_zone!(@zone).local(2026, 8, 6, 12, 0, 0) do
      seed_n_day_streak!(5)

      post streak_commitment_path, params: { days: 3 }, as: :json
      assert_response :unprocessable_entity
      assert_nil @user.reload.streak_commitment_target_days
    end
  end

  test "decline increments declines" do
    seed_climb!(@user, today_mission: "Ship auth")

    post decline_streak_commitment_path
    assert_response :no_content
    assert_equal 1, @user.reload.streak_commit_declines
  end

  test "destroy clears commitment" do
    seed_climb!(@user, today_mission: "Ship auth")
    @user.update!(streak_commitment_target_days: 7, streak_commitment_started_on: @today)

    delete streak_commitment_path
    assert_response :no_content
    @user.reload
    assert_nil @user.streak_commitment_target_days
    assert_nil @user.streak_commitment_started_on
  end

  test "today visit shows progress meta for mid commitment" do
    travel_to Time.find_zone!(@zone).local(2026, 8, 6, 12, 0, 0) do
      seed_n_day_streak!(4)
      @user.update!(
        streak_commitment_target_days: 7,
        streak_commitment_started_on: @today - 3,
        last_streak_moment_on: nil
      )

      get dashboard_path
      assert_response :success
      assert_select ".lp-streak-moment__meta", text: I18n.t("climb.streak_moment.day_of", n: 4, m: 7)
      assert_select ".lp-streak-moment__track"
    end
  end

  test "today visit shows goal once then celebrate next day" do
    travel_to Time.find_zone!(@zone).local(2026, 8, 6, 12, 0, 0) do
      seed_n_day_streak!(7)
      @user.update!(
        streak_commitment_target_days: 7,
        streak_commitment_started_on: @today - 6,
        last_streak_moment_on: nil
      )

      get dashboard_path
      assert_response :success
      assert_select ".lp-streak-moment__did-it", text: I18n.t("climb.streak_moment.you_did_it")
      assert_nil @user.reload.streak_commitment_target_days
    end

    travel_to Time.find_zone!(@zone).local(2026, 8, 7, 12, 0, 0) do
      seed_n_day_streak!(8)
      @user.update!(last_streak_moment_on: nil)

      get dashboard_path
      assert_response :success
      assert_select ".lp-streak-moment__did-it", count: 0
      assert_select ".lp-streak-moment__sub", text: I18n.t("climb.streak_moment.days_in_a_row")
    end
  end

  test "requires authentication" do
    sign_out
    post streak_commitment_path, params: { days: 7 }, as: :json
    assert_redirected_to new_session_path
  end

  private

  def seed_two_day_streak!
    seed_n_day_streak!(2)
  end

  def seed_n_day_streak!(n)
    seed_climb!(@user, today_mission: "Today win") unless @user.strategy_goals.battles.exists?
    project = @user.strategy_goals.find_by!(horizon: "project", title: "Auth")
    journey = @user.primary_focused_journey
    local_today = Battles::WinsOnLocalDate.local_today_for(@user)
    n.times do |i|
      on = local_today - (n - 1 - i)
      title = "Win #{on}"
      battle = project.children.find_by(horizon: "day", title: title)
      battle ||= project.children.create!(
        user: @user,
        life_area: journey.life_area,
        life_journey: journey,
        horizon: "day",
        title: title,
        scheduled_on: on,
        position: project.children.count
      )
      battle.update!(completed_at: Time.find_zone!(@zone).local(on.year, on.month, on.day, 9, 0, 0))
    end
  end
end
