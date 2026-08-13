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
    # Tall window so peeks stay in the grid (short height still hides peeks).
    page.driver.browser.manage.window.resize_to(1400, 1400)

    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"

    within(".lp-dash-nav") { click_link "Mountain" }
    assert_selector "#strategy-world", wait: 5
    assert_selector ".lp-rpg-destination-carousel.is-multi"
    # Title/peek use line-clamp or mask — Capybara visible-text can false-negative as "".
    assert_selector ".lp-rpg-destination-carousel__title", visible: :all, wait: 5
    assert_match(/Ship LifePoints/i, destination_title_text)
    assert_selector ".lp-rpg-destination-carousel__peek.is-next", visible: :all
    assert_match(/Health Summit/i, peek_title_text("next"))
    assert_selector ".lp-rpg-path", text: /Career Path/
    assert_no_selector ".lp-rpg-path", text: /Run Path/
    assert_no_selector ".lp-rpg-goals .lp-rpg-goal"

    find("a.lp-rpg-destination-carousel__arrow.is-next").click

    # Arrow is a Turbo link — wait for the destination switch before reading title text.
    assert_selector ".lp-rpg-path", text: /Run Path/, wait: 5
    assert_no_selector ".lp-rpg-path", text: /Career Path/
    assert_selector ".lp-rpg-destination-carousel__title", visible: :all, wait: 5
    assert_match(/Health Summit/i, destination_title_text)

    find(".lp-rpg-destination-dots__dot[aria-label='Ship LifePoints']").click
    assert_selector ".lp-rpg-path", text: /Career Path/, wait: 5
    assert_no_selector ".lp-rpg-path", text: /Run Path/
    assert_match(/Ship LifePoints/i, destination_title_text)
  end

  test "destination dots stay visible on a 375x667 phone" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"

    within(".lp-dash-nav") { click_link "Mountain" }
    assert_selector "#strategy-world", wait: 5

    # 667 is a common iPhone height; 568 hits the max-height: 600px chrome block
    # that used to hide the dots.
    [ [ 375, 667 ], [ 375, 568 ] ].each do |width, height|
      page.driver.browser.manage.window.resize_to(width, height)
      visit life_journey_path(@journey, goal_id: @goal.id)
      assert_selector ".lp-rpg-destination-dots", wait: 5
      assert_selector ".lp-rpg-destination-dots__dot", visible: :visible, count: 2

      hidden = page.evaluate_script(<<~JS)
        (() => {
          const dots = document.querySelector(".lp-rpg-destination-dots");
          if (!dots) return { missing: true };
          const cs = getComputedStyle(dots);
          const r = dots.getBoundingClientRect();
          return {
            display: cs.display,
            height: r.height,
            width: r.width,
            vh: window.innerHeight
          };
        })()
      JS
      refute hidden["missing"], "destination dots missing at #{width}x#{height}"
      refute_equal "none", hidden["display"], "dots display:none at #{width}x#{height} vh=#{hidden['vh']}"
      assert_operator hidden["height"], :>, 0, "dots have no height at #{width}x#{height}"
    end
  end

  test "new destination coach creates a third summit with its own spine" do
    page.driver.browser.manage.window.resize_to(1400, 1400)

    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"

    within(".lp-dash-nav") { click_link "Mountain" }
    assert_selector ".lp-rpg-destination", wait: 5

    find(".lp-rpg-destination-add", wait: 3).click
    assert_selector "dialog#destination-coach[open]", wait: 3
    fill_in "destination-coach-title", with: "Family Peak"
    find("#destination-coach [data-destination-coach-target='continue']").click
    fill_in "destination-coach-plan", with: "Weekend dinners"
    find("#destination-coach [data-destination-coach-target='continue']").click
    fill_in "destination-coach-action", with: "Text the family group"
    find("#destination-coach [data-destination-coach-target='submit']").click

    assert_current_path dashboard_path, wait: 8
    family = StrategyGoal.for_kind("goal").roots.find_by!(title: "Family Peak")
    refute_equal @goal.id, family.id
    refute_equal @other.id, family.id
    plans = family.children.select(&:plan?)
    assert_equal [ "Weekend dinners" ], plans.map(&:title)
    assert_equal 0, @goal.children.select(&:plan?).count { |p| p.title == "Weekend dinners" }
  end

  private

  def destination_title_text
    page.evaluate_script(<<~JS)
      (document.querySelector(".lp-rpg-destination-carousel__title")?.textContent || "").trim()
    JS
  end

  def peek_title_text(side)
    page.evaluate_script(<<~JS)
      (document.querySelector(".lp-rpg-destination-carousel__peek.is-#{side} .lp-rpg-destination-carousel__peek-title")?.textContent || "").trim()
    JS
  end
end
