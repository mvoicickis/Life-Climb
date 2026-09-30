# frozen_string_literal: true

require "test_helper"

class TodayEmptyBattleCtaControllerTest < ActionDispatch::IntegrationTest
  include ClimbTestHelper

  setup do
    @user = users(:one)
    sign_in_as @user
  end

  def clear_today_battles!(journey)
    area = journey.life_area
    @user.strategy_goals.where(life_area_id: area.id, horizon: "day", scheduled_on: Date.current).destroy_all
    @user.daily_todos.for_day(Date.current).destroy_all
  end

  def assert_empty_battle_pill!(label:, href_includes:)
    get dashboard_path
    assert_response :success
    assert_select ".lp-today-empty-cta__pill", text: label, count: 1
    assert_select "a.lp-today-empty-cta__pill[href*='#{href_includes}']", count: 1
    assert_select ".lp-today-v2-empty", count: 0
    assert_select "a.is-open", count: 0
  end

  test "empty battlefield shows set goal when strategy goal is missing" do
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Ship LifePoints",
      ideal_scene: "App live",
      current_reality: "Building",
      next_win: "Launch",
      today_mission: "Ship one thing",
      closer_percent: 20,
      route_mission: false
    )
    @journey = @user.reload.primary_focused_journey
    @user.update!(character: @user.character.presence || "fox")
    dismiss_onboarding_missions!(@user)
    clear_today_battles!(@journey)

    assert_empty_battle_pill!(
      label: I18n.t("dash.battlefield.empty_cta.set_goal"),
      href_includes: "/life_journeys/#{ @journey.id }"
    )
  end

  test "empty battlefield shows add next camp when project is missing" do
    @journey = seed_climb!(@user, today_mission: "Ship")
    dismiss_onboarding_missions!(@user)
    goal = @user.strategy_goals.for_kind("goal").roots.first
    plan = goal.children.find(&:plan?)
    plan.children.destroy_all
    clear_today_battles!(@journey)

    assert_empty_battle_pill!(
      label: I18n.t("dash.battlefield.empty_cta.add_next_camp"),
      href_includes: "open_plant=1"
    )
  end

  test "empty battlefield shows add todays battle when camp has no battles" do
    @journey = seed_climb!(@user, today_mission: "Ship")
    dismiss_onboarding_missions!(@user)
    goal = @user.strategy_goals.for_kind("goal").roots.first
    plan = goal.children.find(&:plan?)
    project = plan.children.find(&:project?)
    project.children.destroy_all
    clear_today_battles!(@journey)

    assert_empty_battle_pill!(
      label: I18n.t("dash.battlefield.empty_cta.add_todays_battle"),
      href_includes: "open_camp=#{project.id}"
    )
    assert_select "a.lp-today-empty-cta__pill[href*='open_composer=1']", count: 1
  end

  test "empty battlefield shows add todays battle when camp has battles not on today" do
    @journey = seed_climb!(@user, today_mission: "Ship")
    dismiss_onboarding_missions!(@user)
    goal = @user.strategy_goals.for_kind("goal").roots.first
    plan = goal.children.find(&:plan?)
    project = plan.children.find(&:project?)
    project.children.create!(
      user: @user, life_area: @journey.life_area, life_journey: @journey,
      horizon: "day", title: "Later fight", scheduled_on: 1.week.from_now.to_date, position: 0
    )
    clear_today_battles!(@journey)

    assert_empty_battle_pill!(
      label: I18n.t("dash.battlefield.empty_cta.add_todays_battle"),
      href_includes: "open_camp=#{project.id}"
    )
  end
end
