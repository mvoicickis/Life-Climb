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
    @user.update!(support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ], character: "fox")
    @journey = @user.reload.primary_focused_journey
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    @goal.children.create!(
      user: @user, life_area: @journey.life_area, life_journey: @journey,
      horizon: "plan", title: "Career Path", position: 0
    ).children.create!(
      user: @user, life_area: @journey.life_area, life_journey: @journey,
      horizon: "project", title: "Resume Camp", position: 0
    )
  end

  test "mountain shows one static destination with no switching or create UI" do
    page.driver.browser.manage.window.resize_to(1400, 1400)

    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"

    within(".lp-dash-nav") { click_link "Mountain" }
    assert_selector "#strategy-world", wait: 5

    assert_selector ".lp-rpg-destination-carousel.is-single"
    assert_selector ".lp-rpg-destination-carousel__title", visible: :all, wait: 5
    assert_match(/Ship LifePoints/i, destination_title_text)
    assert_selector ".lp-rpg-path", text: /Career Path/

    # Switching + "New Destination" create affordances are gone.
    assert_no_selector ".lp-rpg-destination-carousel.is-multi"
    assert_no_selector ".lp-rpg-destination-carousel__arrow"
    assert_no_selector ".lp-rpg-destination-carousel__peek"
    assert_no_selector ".lp-rpg-destination-dots"
    assert_no_selector ".lp-rpg-destination-swipe-hint"
    assert_no_selector ".lp-rpg-destination-add"
    assert_no_selector ".lp-rpg-destination-menu__item[data-action*='destination-switcher#openCreate']"

    # Rename stays available.
    assert_selector ".lp-rpg-destination-menu__btn[data-action*='plan-card-menu#toggle']"
  end

  private

  def destination_title_text
    page.evaluate_script(<<~JS)
      (document.querySelector(".lp-rpg-destination-carousel__title")?.textContent || "").trim()
    JS
  end
end
