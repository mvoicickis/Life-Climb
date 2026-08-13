# frozen_string_literal: true

require "test_helper"

class InstallOfferBannerTest < ActionDispatch::IntegrationTest
  include ClimbTestHelper

  setup do
    @user = users(:one)
    @user.update!(
      character: "fox",
      support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY, User::DAY_SHIELD_TIP_KEY ],
      install_offer_dismiss_count: 0,
      install_offer_dismissed_at: nil,
      install_offer_installed_at: nil
    )
    sign_in_as @user
    seed_climb!(@user, today_mission: "Ship auth")
    # seed_climb! resets milestones — keep shield tip dismissed so install can take the second notice seat.
    @user.update!(
      support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY, User::DAY_SHIELD_TIP_KEY ]
    )
    @journey = @user.primary_focused_journey
    @area = @journey.life_area
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    @plan = @goal.children.find(&:plan?)
    @section = @plan.children.find(&:project?)
    @leaf = @section.children.find(&:project?)

    @leaf.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Write tests", scheduled_on: Date.current, position: 1
    )
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)
  end

  test "tip absent before any battle win" do
    @user.daily_todos.update_all(completed_at: nil)
    refute @user.battle_won_once?

    get dashboard_path
    assert_response :success
    assert_select "[data-install-offer-tip]", count: 0
  end

  test "tip markup present after first win and outside next-action slot" do
    todo = @user.daily_todos.for_day(Date.current).find_by!(title: "Write tests")
    todo.update!(completed_at: Time.current)
    # Keep stack slots free for next-action + install (level-up would take the second seat).
    @journey.update!(commitment_key: "hard", commitment_met_streak_days: 0)
    assert @user.install_offer_eligible?

    get dashboard_path
    assert_response :success

    assert_select "[data-commitment-level-up]", count: 0
    assert_select "[data-day-shield-tip]", count: 0
    assert_select "[data-install-offer-tip='true']", count: 1
    assert_select "#next-action-slot [data-install-offer-tip]", count: 0
    assert_match(/Morning nudge on your home screen/, response.body)
  end

  test "tip still allows next-action to render" do
    todo = @user.daily_todos.for_day(Date.current).find_by!(title: "Write tests")
    todo.update!(completed_at: Time.current)
    @journey.update!(commitment_key: "hard", commitment_met_streak_days: 0)

    get dashboard_path
    assert_response :success

    assert_select "[data-install-offer-tip='true']", count: 1
    assert_select "#next-action-slot", count: 1
  end

  test "tip absent after max dismissals" do
    todo = @user.daily_todos.for_day(Date.current).find_by!(title: "Write tests")
    todo.update!(completed_at: Time.current)
    @user.update!(
      install_offer_dismiss_count: 2,
      install_offer_dismissed_at: 60.days.ago
    )

    get dashboard_path
    assert_response :success
    assert_select "[data-install-offer-tip]", count: 0
  end

  test "settings always includes install offer row" do
    get settings_path
    assert_response :success
    assert_select "#you-row-install-offer", count: 1
    assert_match(/Add to home screen/, response.body)
  end
end
