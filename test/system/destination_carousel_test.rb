# frozen_string_literal: true

require "application_system_test_case"

class DestinationCarouselTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Ship LifePoints",
      ideal_scene: "App live",
      current_reality: "Building",
      next_win: "Launch",
      today_mission: "Write tests",
      closer_percent: 20,
      route_mission: true
    )
    @user.update!(support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ], character: "fox", mountain_trail_tour_ack: 7)
    @journey = @user.reload.primary_focused_journey
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    @plan = @goal.children.create!(
      user: @user, life_area: @journey.life_area, life_journey: @journey,
      horizon: "plan", title: "Career Path", position: 0
    ).tap do |plan|
      plan.children.create!(
        user: @user, life_area: @journey.life_area, life_journey: @journey,
        horizon: "project", title: "Resume Camp", position: 0
      )
    end
  end

  test "mountain shows one static destination with no switching or create UI" do
    page.driver.browser.manage.window.resize_to(390, 844)

    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-nav", wait: 8

    visit life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id)
    assert_selector "#strategy-world.lp-rpg.is-v4-phone", wait: 10
    assert_selector "#mountain-trail.lp-trail.is-v4", wait: 10

    assert_selector ".lp-trail__peak-title.lp-rpg-destination-carousel__title", visible: :all, wait: 5
    assert_match(/Ship LifePoints/i, destination_title_text)

    # Switching + "New Destination" create affordances are gone.
    assert_no_selector ".lp-rpg-destination-carousel.is-single"
    assert_no_selector ".lp-rpg-destination-carousel.is-multi"
    assert_no_selector ".lp-rpg-destination-carousel__arrow"
    assert_no_selector ".lp-rpg-destination-carousel__peek"
    assert_no_selector ".lp-rpg-destination-dots"
    assert_no_selector ".lp-rpg-destination-swipe-hint"
    assert_no_selector ".lp-rpg-destination-add"
    assert_no_selector ".lp-rpg-plan-rail"
    assert_no_selector ".lp-rpg-path"

    # Rename stays available via peak flag menu → destination edit dialog.
    assert_selector ".lp-trail__flag[data-action*='trail-canvas#togglePeakMenu']"
    assert_selector "dialog#destination-edit-#{@goal.id}", visible: :all
    assert_selector ".lp-trail__peak-item", text: /Edit Destination/i, visible: :all
  end

  private

  def destination_title_text
    page.evaluate_script(<<~JS)
      (document.querySelector(".lp-trail__peak-title")?.textContent || "").trim()
    JS
  end
end
