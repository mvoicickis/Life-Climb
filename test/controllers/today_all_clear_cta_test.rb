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
