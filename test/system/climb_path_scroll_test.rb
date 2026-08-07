# frozen_string_literal: true

require "application_system_test_case"

# Replaces the old horizontal section-arrow suite — climb path scrolls vertically.
class ClimbPathScrollTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    page.driver.browser.manage.window.resize_to(390, 844)

    Onboarding::Run.call(
      user: @user, area_key: "career", title: "Ship LifePoints",
      ideal_scene: "App live", current_reality: "Building", next_win: "Launch",
      today_mission: "Write tests", closer_percent: 20, route_mission: true
    )
    @user.update!(support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ], character: "fox")
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    @plan = @goal.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: "Main trail", position: 0
    )
    @camps = 6.times.map do |i|
      camp = @plan.children.create!(
        user: @user, life_area: @area, life_journey: @journey,
        horizon: "project", title: "Camp #{i + 1}", position: i
      )
      camp.complete! if i < 2
      camp
    end
  end

  test "vertical climb path scrolls and keeps current companion pin" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-nav", wait: 5

    visit life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @camps[2].id)
    assert_selector ".lp-climb-path", wait: 5
    assert_selector ".lp-rpg__stage-trail", wait: 5
    assert_selector ".lp-climb-path__node.is-done", minimum: 2
    assert_selector ".lp-climb-path__node.is-current", wait: 5
    assert_selector ".lp-climb-path__face", wait: 5
    assert_selector ".lp-climb-path__node.is-locked", minimum: 1
    assert_no_selector ".lp-rpg-sections__arrow"
    assert_no_selector ".lp-rpg-section-card"

    page.execute_script(<<~JS)
      const trail = document.querySelector('.lp-rpg__stage-trail');
      if (trail) trail.scrollTop = trail.scrollHeight;
    JS
    assert_selector ".lp-climb-path__new-btn", visible: :all, wait: 5
  end
end
