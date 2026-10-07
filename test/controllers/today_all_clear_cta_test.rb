# frozen_string_literal: true

require "test_helper"

class TodayAllClearCtaTest < ActionDispatch::IntegrationTest
  include ClimbTestHelper

  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "all clear shows add another battle with open composer" do
    @journey = seed_climb!(@user, today_mission: "Ship auth")
    dismiss_onboarding_missions!(@user)
    @area = @journey.life_area
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)
    todo = @user.daily_todos.for_day(Date.current).find_by!(title: "Ship auth")
    todo.update!(completed_at: Time.current)

    get dashboard_path
    assert_response :success

    assert_select "#today-battlefield-end-day-host .lp-today-empty-cta__pill",
                  text: I18n.t("dash.battlefield.add_another_battle")
    assert_select "a.lp-today-empty-cta__pill[href*='open_composer=1']", count: 1
    assert_select ".lp-today-battlefield-end-day__btn", count: 0
  end

  test "all clear opens trail current camp when stage order differs from position" do
    user = User.create!(
      name: "Multi camp all clear",
      email_address: "multi-camp-clear-#{SecureRandom.hex(4)}@example.com",
      password: "password12345",
      password_confirmation: "password12345",
      planning_version: 2,
      onboarding_completed_at: Time.current
    )
    sign_in_as user

    bootstrap = Onboarding::Bootstrap.call(
      user: user,
      goal_title: "Climb",
      camp_titles: [ "Camp A" ]
    )
    journey = bootstrap.journey
    area = journey.life_area
    goal = bootstrap.goal
    plan = goal.children.for_kind("plan").not_holding.first
    camp_a = bootstrap.projects.first
    camp_a.update_columns(position: 3, stage: 0)
    battle_a = camp_a.children.for_kind("day").first
    Strategy::CascadeToDaily.call(user: user, life_area: area)
    user.daily_todos.for_day(Date.current).where(strategy_goal_id: battle_a.id).find_each do |todo|
      todo.update!(completed_at: Time.current)
    end
    battle_a.complete!
    camp_a.complete!

    camp_b = plan.children.create!(
      user: user, life_area: area, life_journey: journey, horizon: "project",
      title: "Camp B", position: 0, stage: 1
    )
    plan.children.create!(
      user: user, life_area: area, life_journey: journey, horizon: "project",
      title: "Camp C", position: 1, stage: 2
    )
    plan.children.create!(
      user: user, life_area: area, life_journey: journey, horizon: "project",
      title: "Camp D", position: 2, stage: 3
    )

    battle = camp_b.children.create!(
      user: user, life_area: area, life_journey: journey, horizon: "day",
      title: "B today", scheduled_on: Date.current, position: 0
    )
    Strategy::CascadeToDaily.call(user: user, life_area: area)
    todo = user.daily_todos.for_day(Date.current).find_by!(strategy_goal_id: battle.id)
    todo.update!(completed_at: Time.current)
    battle.complete!
    dismiss_onboarding_missions!(user)

    assert_equal camp_b, Strategy::PathProject.resolve(user: user, journey: journey)

    get dashboard_path
    assert_response :success

    href = assert_select("#today-battlefield-end-day-host a.lp-today-empty-cta__pill").first["href"]
    query = Rack::Utils.parse_query(URI.parse(href).query)
    assert_equal camp_b.id.to_s, query["open_camp"]
    assert_equal "1", query["open_composer"]
  end

  test "all clear camp cleared today includes open_camp for path project" do
    user = User.create!(
      name: "Camp cleared handoff",
      email_address: "camp-cleared-#{SecureRandom.hex(4)}@example.com",
      password: "password12345",
      password_confirmation: "password12345",
      planning_version: 2,
      onboarding_completed_at: Time.current
    )
    sign_in_as user

    bootstrap = Onboarding::Bootstrap.call(
      user: user,
      goal_title: "Bal climb",
      camp_titles: [ "Bal" ]
    )
    journey = bootstrap.journey
    camp = bootstrap.projects.first
    battle = camp.children.for_kind("day").first
    battle.update!(completed_at: Time.current, scheduled_on: Date.current)
    Strategy::CascadeToDaily.call(user: user, life_area: journey.life_area)
    todo = user.daily_todos.for_day(Date.current).find_by!(strategy_goal_id: battle.id)
    todo.update!(completed_at: Time.current)
    dismiss_onboarding_missions!(user)

    path_camp = Strategy::PathProject.resolve(user: user, journey: journey)
    assert_equal camp, path_camp
    refute camp.completed?
    assert journey.first_camp_reveal_pending?

    get dashboard_path
    assert_response :success

    href = assert_select("#today-battlefield-end-day-host a.lp-today-empty-cta__pill").first["href"]
    query = Rack::Utils.parse_query(URI.parse(href).query)
    assert_equal path_camp.id.to_s, query["open_camp"]
    assert_equal "1", query["open_composer"]
  end

  test "summit handoff shows summit pill and grey add another camp link" do
    user = User.create!(
      name: "Summit all clear",
      email_address: "summit-all-clear-#{SecureRandom.hex(4)}@example.com",
      password: "password12345",
      password_confirmation: "password12345",
      planning_version: 2,
      onboarding_completed_at: Time.current
    )
    sign_in_as user

    bootstrap = Onboarding::Bootstrap.call(
      user: user,
      goal_title: "Peak goal",
      camp_titles: [ "Camp one" ]
    )
    journey = bootstrap.journey
    camp = bootstrap.projects.first
    battle = camp.children.for_kind("day").first
    battle.update!(completed_at: Time.current, scheduled_on: Date.current)
    Strategy::CascadeToDaily.call(user: user, life_area: journey.life_area)
    todo = user.daily_todos.for_day(Date.current).find_by!(strategy_goal_id: battle.id)
    todo.update!(completed_at: Time.current)
    camp.complete!
    dismiss_onboarding_missions!(user)

    get dashboard_path
    assert_response :success

    assert_select "#today-battlefield-end-day-host a.lp-today-empty-cta__pill[href*='summit_next_goal']",
                  count: 1
    assert_select "#today-battlefield-end-day-host a.lp-today-all-clear__secondary[href*='open_plant=1']",
                  text: I18n.t("summit_next_goal.add_another_camp")
  end

  test "uncomplete turbo stream clears all clear host" do
    @journey = seed_climb!(@user, today_mission: "Ship auth")
    dismiss_onboarding_missions!(@user)
    @area = @journey.life_area
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)
    @todo = @user.daily_todos.for_day(Date.current).find_by!(title: "Ship auth")

    post complete_daily_todo_path(@todo), as: :turbo_stream
    assert_response :ok
    assert_match "lp-today-empty-cta__pill", response.body

    post complete_daily_todo_path(@todo), as: :turbo_stream
    assert_response :ok
    assert_match %(action="update" target="today-battlefield-end-day-host"), response.body
    assert_no_match "lp-today-empty-cta__pill", response.body
  end
end
