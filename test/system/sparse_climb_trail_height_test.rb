# frozen_string_literal: true

require "application_system_test_case"

# Mountain V4 photo trail: fixed 100dvh shell with an internal photo scroller.
class SparseClimbTrailHeightTest < ApplicationSystemTestCase
  PHONE_W = 390
  PHONE_H = 844

  setup do
    @user = users(:one)
    @user.update!(character: "fox", support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ])
    lock_phone_viewport!(PHONE_W, PHONE_H)

    Onboarding::Run.call(
      user: @user, area_key: "career", title: "Ship LifePoints",
      ideal_scene: "App live", current_reality: "Building", next_win: "Launch",
      today_mission: "Write tests", closer_percent: 20, route_mission: true
    )
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    @plan = @goal.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: "Learn German", position: 0
    )
    @camp = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Duolingo", position: 0
    )
    leaf = practice_leaf_for!(@camp, title: "Steps")
    host = Strategy::EnsureFolderQuest.call(folder: leaf)
    host.practice_tasks.create!(user: @user, title: "Do a lesson", position: 0)
  end

  private

  def lock_phone_viewport!(width, height)
    page.driver.browser.manage.window.resize_to(width, height)
    page.driver.browser.execute_cdp(
      "Emulation.setDeviceMetricsOverride",
      width: width,
      height: height,
      deviceScaleFactor: 1,
      mobile: true
    )
  end
end
