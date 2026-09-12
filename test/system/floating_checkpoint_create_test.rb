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
    assert_selector ".lp-trail-plant.is-open .lp-trail-plant__title", text: /New Camp/i
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
      find("input.lp-trail-plant__field").set("Notifications camp")
      find(".lp-trail-plant__submit").click
    end

    # postPlant fetch + Turbo.renderStreamMessage + hidePlant — wait for replace, not submit.
    assert_no_selector ".lp-trail-plant.is-open", wait: 10
    assert_selector "#trail-map-camps", wait: 10

    created = @plan.reload.children.for_kind("project").find_by!(title: "Notifications camp")
    assert_camp_tent_on_map!(created)
    assert_no_selector ".lp-rpg-section-head"

    FileUtils.mkdir_p("/opt/cursor/artifacts/screenshots")
    page.save_screenshot("/opt/cursor/artifacts/screenshots/checkpoint-create-visible.png")
  end

  private

  def assert_camp_tent_on_map!(camp)
    selector = "#trail-map-camps #trail-camp-#{camp.id}[aria-label='#{camp.title}']"
    assert_selector selector, visible: :all, wait: 10
  rescue Minitest::Assertion => e
    map_html = page.find("#trail-map-camps", visible: :all)["outerHTML"]
    flunk "#{e.message}\n\n#trail-map-camps at failure:\n#{map_html}"
  end
end
