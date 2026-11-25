# frozen_string_literal: true

require "test_helper"

class FirstTipsTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      name: "Alex",
      email_address: "first-tips-#{SecureRandom.hex(4)}@example.com",
      password: "password12345",
      password_confirmation: "password12345",
      onboarding_completed_at: Time.current
    )
    @result = Onboarding::Bootstrap.call(
      user: @user,
      goal_title: "Ship",
      camp_titles: [ "Launch" ],
      complete_onboarding: false
    )
    @journey = @result.journey
    mark_onboarding_v3!(@journey)
    Onboarding::PlantBattles.call(
      user: @user,
      journey: @journey,
      battle_titles: [ "Battle one" ]
    )
  end

  test "returns nil for non-v3 journey" do
    @journey.update!(setup_flags: {})

    tip = FirstTips.next_tip_for(
      user: @user,
      page: :today,
      context: today_ctx(open_battle_count: 1)
    )

    assert_nil tip
  end

  test "circle on today with open battle and no win yet" do
    tip = FirstTips.next_tip_for(
      user: @user,
      page: :today,
      context: today_ctx(open_battle_count: 1)
    )

    assert_equal "circle", tip[:key]
    assert_includes tip[:selector], "lp-today-v2-row__box"
  end

  test "mountain after first win when circle skipped" do
    win_first_battle!(@user)

    tip = FirstTips.next_tip_for(
      user: @user,
      page: :today,
      context: today_ctx(open_battle_count: 0)
    )

    assert_equal "mountain", tip[:key]
  end

  test "mountain still shows on day two after first win" do
    @user.update!(onboarding_completed_at: 2.days.ago)
    win_first_battle!(@user)

    tip = FirstTips.next_tip_for(
      user: @user,
      page: :today,
      context: today_ctx(open_battle_count: 0)
    )

    assert_equal "mountain", tip[:key]
  end

  test "camp on mountain after mountain seen" do
    @user.mark_first_tip_seen!("mountain")

    tip = FirstTips.next_tip_for(
      user: @user,
      page: :mountain,
      context: mountain_ctx
    )

    assert_equal "camp", tip[:key]
  end

  test "camp on mountain when base camp intro still needed" do
    @user.mark_first_tip_seen!("mountain")
    assert @user.needs_base_camp_intro?

    tip = FirstTips.next_tip_for(
      user: @user,
      page: :mountain,
      context: mountain_ctx
    )

    assert_equal "camp", tip[:key]
  end

  test "habit on today from day two with no on-home habits" do
    @user.update!(onboarding_completed_at: 1.day.ago)
    %w[circle mountain camp animal].each { |key| @user.mark_first_tip_seen!(key) }

    tip = FirstTips.next_tip_for(
      user: @user,
      page: :today,
      context: today_ctx(open_battle_count: 0)
    )

    assert_equal "habit", tip[:key]
    assert_equal FirstTips::Presenter::HABIT_ADD_SELECTOR, tip[:habit_add_selector]
  end

  test "animal on you from day two" do
    @user.update!(onboarding_completed_at: 1.day.ago)
    %w[circle mountain camp habit].each { |key| @user.mark_first_tip_seen!(key) }

    tip = FirstTips.next_tip_for(
      user: @user,
      page: :you,
      context: you_ctx
    )

    assert_equal "animal", tip[:key]
  end

  test "third non-circle tip same day blocked by budget" do
    win_first_battle!(@user)
    @user.mark_first_tip_seen!("mountain")
    @user.record_first_tip_shown_today!("mountain")
    @user.record_first_tip_shown_today!("camp")

    tip = FirstTips.next_tip_for(
      user: @user,
      page: :mountain,
      context: mountain_ctx
    )

    assert_nil tip
  end

  test "circle does not consume daily budget" do
    @user.record_first_tip_shown_today!("mountain")
    @user.record_first_tip_shown_today!("camp")
    refute @user.first_tip_daily_budget_available?

    tip = FirstTips.next_tip_for(
      user: @user,
      page: :today,
      context: today_ctx(open_battle_count: 1)
    )

    assert_equal "circle", tip[:key]
  end

  test "blocked when overlays flagged in context" do
    tip = FirstTips.next_tip_for(
      user: @user,
      page: :today,
      context: today_ctx(open_battle_count: 1, streak_moment: true)
    )

    assert_nil tip
  end

  test "read-only impersonation context returns nil" do
    tip = FirstTips.next_tip_for(
      user: @user,
      page: :today,
      context: today_ctx(open_battle_count: 1, read_only_impersonation: true)
    )

    assert_nil tip
  end

  private

  def mark_onboarding_v3!(journey)
    flags = (journey.setup_flags.presence || {}).stringify_keys.merge(
      Onboarding::Bootstrap::ONBOARDING_V3_FLAG => "true"
    )
    journey.update_columns(setup_flags: flags, updated_at: Time.current)
    journey.setup_flags = flags
  end

  def today_ctx(open_battle_count:, **opts)
    FirstTips::Context.new(page: :today, open_battle_count:, **opts)
  end

  def mountain_ctx
    FirstTips::Context.new(page: :mountain)
  end

  def you_ctx
    FirstTips::Context.new(page: :you)
  end

  def win_first_battle!(user)
    todo = user.daily_todos.where(completed_at: nil).first
    assert todo, "expected an open battle"
    todo.update!(completed_at: Time.current)
    assert user.reload.battle_won_once?
  end
end
