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
    @user.update!(support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ])
    @journey = @user.reload.primary_focused_journey
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    @other = @user.strategy_goals.create!(
      life_area: @journey.life_area, life_journey: @journey,
      horizon: "goal", title: "Health Summit", position: 1
    )
    career_camp = @goal.children.create!(
      user: @user, life_area: @journey.life_area, life_journey: @journey,
      horizon: "plan", title: "Career Path", position: 0
    ).children.create!(
      user: @user, life_area: @journey.life_area, life_journey: @journey,
      horizon: "project", title: "Resume Camp", position: 0
    )
    practice_leaf_for!(career_camp).children.create!(
      user: @user, life_area: @journey.life_area, life_journey: @journey,
      horizon: "day", title: "Write CV", scheduled_on: Date.current, position: 0
    )
    run_camp = @other.children.create!(
      user: @user, life_area: @journey.life_area, life_journey: @journey,
      horizon: "plan", title: "Run Path", position: 0
    ).children.create!(
      user: @user, life_area: @journey.life_area, life_journey: @journey,
      horizon: "project", title: "5k Camp", position: 0
    )
    practice_leaf_for!(run_camp).children.create!(
      user: @user, life_area: @journey.life_area, life_journey: @journey,
      horizon: "day", title: "Jog", scheduled_on: Date.current, position: 0
    )
  end

  test "destination carousel shows one active world and arrow focus switch updates missions" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"

    within(".lp-dash-nav") { click_link "Mountain" }
    assert_selector "#strategy-world", wait: 5
    assert_selector ".lp-rpg-destination-carousel.is-multi"
    # Title uses -webkit-box/line-clamp — Capybara visible-text can false-negative as "".
    assert_selector ".lp-rpg-destination-carousel__title", visible: :all, wait: 5
    assert_match(/Ship LifePoints/i, destination_title_text)
    assert_selector ".lp-rpg-destination-carousel__peek.is-next", text: /Health Summit/i
    assert_selector ".lp-rpg-path", text: /Career Path/
    assert_no_selector ".lp-rpg-path", text: /Run Path/
    assert_no_selector ".lp-rpg-goals .lp-rpg-goal"

    find(".lp-rpg-destination-carousel__arrow.is-next").click

    assert_selector ".lp-rpg-destination-carousel__title", visible: :all, wait: 5
    assert_match(/Health Summit/i, destination_title_text)
    assert_selector ".lp-rpg-path", text: /Run Path/
    assert_no_selector ".lp-rpg-path", text: /Career Path/
  end

  test "new destination sheet creates and activates the destination" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"

    within(".lp-dash-nav") { click_link "Mountain" }
    assert_selector ".lp-rpg-destination", wait: 5

    find(".lp-rpg-destination-menu__btn", wait: 3).click
    assert_selector ".lp-rpg-destination-menu:not([hidden])", wait: 3
    find(".lp-rpg-destination-menu__item", text: /New Destination/i).click
    assert_selector "dialog#destination-create[open]", wait: 3
    fill_in "destination-create-title", with: "Family Peak"
    page.execute_script(<<~JS)
      document.querySelector("#destination-create form")?.requestSubmit()
    JS

    assert_selector "#first-climb-coach", wait: 8
    assert StrategyGoal.for_kind("goal").roots.exists?(title: "Family Peak")
    assert_match(/goal_id=\d+/, page.current_url)
  end

  private

  def destination_title_text
    page.evaluate_script(<<~JS)
      (document.querySelector(".lp-rpg-destination-carousel__title")?.textContent || "").trim()
    JS
  end
end
