# frozen_string_literal: true

require "application_system_test_case"

class StatsFinishedCampSheetTest < ApplicationSystemTestCase
  include ClimbTestHelper

  setup do
    @user = users(:one)
    journey = seed_climb!(@user, today_mission: "Stats camp sheet")
    dismiss_onboarding_missions!(@user)
    @journey = journey
    @area = journey.life_area
    goal = @user.strategy_goals.for_area(@area.id).for_kind("goal").roots.first
    @plan = goal.children.find { |c| c.plan? && !c.holding? }
    @goal = goal
    @project = @plan.children.create!(
      user: @user,
      life_area: @area,
      life_journey: @journey,
      horizon: "project",
      title: "Finished camp",
      position: 99,
      color_key: "teal",
      trail_x: 0.48,
      trail_y: 0.72
    )
    battle = @project.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Daily habit", scheduled_on: Date.current, position: 0,
      repeat: "daily"
    )
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)
    todo = @user.daily_todos.for_day.find_by!(strategy_goal_id: battle.id)
    Battles::CompleteTodo.call(todo: todo, user: @user, session: {})
    @project.manually_complete!
  end

  test "stats camp row opens settled sheet on mountain at 360px" do
    page.driver.browser.manage.window.resize_to(360, 700)

    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_today_v2_shell!

    visit life_points_path
    assert_selector ".lp-stats-row", wait: 5
    click_link @project.title

    assert_selector ".lp-trail-sheet.is-open", wait: 5
    assert_selector "#trail-camp-finish-#{@project.id} [data-trail-camp-finish-target='settledCard']", wait: 5
    assert_selector "#trail-camp-finish-#{@project.id} button", text: I18n.t("strategy.rpg.trail.finish_camp_card.reopen_camp")
    assert_no_selector "#trail-map-camps #trail-camp-#{@project.id}"
  end
end
