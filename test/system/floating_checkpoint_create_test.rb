# frozen_string_literal: true

require "application_system_test_case"

class FloatingCheckpointCreateTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    page.driver.browser.manage.window.resize_to(390, 700)

    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Ship the MVP",
      ideal_scene: "App live",
      current_reality: "Building",
      next_win: "Launch",
      today_mission: "Design battle card",
      closer_percent: 40,
      route_mission: true
    )
    @user.update!(support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ], character: "fox")
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    @plan = @goal.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: "MVP path", position: 0
    )
    camps = [
      "Authentication",
      "Daily battles",
      "Dashboard"
    ].each_with_index.map do |title, i|
      @plan.children.create!(
        user: @user, life_area: @area, life_journey: @journey,
        horizon: "project", title: title, position: i
      )
    end
    camps[0].complete!
    practice_leaf_for!(camps[1]).children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Design battle card",
      scheduled_on: Date.current, position: 0
    )
    @current = camps[1]
  end

  test "path focus place checkpoint opens add form" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-nav", wait: 5
    within(".lp-dash-nav") { click_link "Mountain" }
    assert_selector "#strategy-world", wait: 5

    visit life_journey_path(@journey.reload, goal_id: @goal.id, plan_id: @plan.id, focus_id: @current.id)
    assert_selector "#strategy-world.lp-rpg.is-focus-phase", wait: 5
    assert_no_selector ".lp-first-climb-shell"
    assert_selector "#mountain-trail.lp-trail.is-v4", wait: 5

    open_v4_plant_composer!
    assert_selector ".lp-trail-plant.is-open .lp-trail-plant__title", text: /New project/i
    assert_selector ".lp-trail-plant.is-open input[name='title']"
    assert_selector ".lp-trail-plant.is-open .lp-trail-plant__submit"

    FileUtils.mkdir_p("/opt/cursor/artifacts/screenshots")
    page.save_screenshot("/opt/cursor/artifacts/screenshots/mountain-checkpoint-float-create.png")
  end

  test "create checkpoint saves and keeps the new camp visible in sections" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-nav", wait: 5

    visit life_journey_path(@journey.reload, goal_id: @goal.id, plan_id: @plan.id, focus_id: @current.id)
    assert_selector "#strategy-world.lp-rpg.is-focus-phase", wait: 5
    assert_selector "#mountain-trail.lp-trail.is-v4", wait: 5

    open_v4_plant_composer!
    within(".lp-trail-plant.is-open") do
      find(".lp-trail-plant__field").set("Notifications camp")
      find(".lp-trail-plant__submit").click
    end
    assert_selector ".lp-trail.is-placing", wait: 3

    assert_difference -> { @plan.reload.children.for_kind("project").count }, 1 do
      page.execute_script(<<~JS)
        (() => {
          const mountain = document.querySelector(".lp-trail__mountain");
          if (!mountain) return;
          const r = mountain.getBoundingClientRect();
          const x = r.left + r.width * 0.52;
          const y = r.top + r.height * 0.58;
          mountain.dispatchEvent(new MouseEvent("click", {
            bubbles: true, cancelable: true, clientX: x, clientY: y, view: window
          }));
        })()
      JS
      assert_selector ".lp-trail-camp[aria-label='Notifications camp']", visible: :all, wait: 8
    end
    created = @plan.children.for_kind("project").find_by!(title: "Notifications camp")
    assert_selector "#trail-camp-#{created.id}[aria-label='Notifications camp']", visible: :all, wait: 5
    assert_no_selector ".lp-rpg-section-head"

    FileUtils.mkdir_p("/opt/cursor/artifacts/screenshots")
    page.save_screenshot("/opt/cursor/artifacts/screenshots/checkpoint-create-visible.png")
  end
end
