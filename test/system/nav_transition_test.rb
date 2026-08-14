# frozen_string_literal: true

require "application_system_test_case"

class NavTransitionSystemTest < ApplicationSystemTestCase
  include ClimbTestHelper

  setup do
    @user = users(:one)
    @journey = seed_climb!(@user)
  end

  test "Mountain and Today still switch through the nav" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-nav", wait: 5

    within(".lp-dash-nav") { click_link "Mountain" }
    assert_selector "#strategy-world", wait: 5

    within(".lp-dash-nav") { click_link "Today" }
    assert_selector ".lp-dash", wait: 5

    within(".lp-dash-nav") { click_link "Mountain" }
    assert_selector "#strategy-world", wait: 5
  end

  test "direction is opted-in only" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-nav", wait: 5

    dirs = page.evaluate_script(<<~JS)
      ({
        forward: window.lpNavDirection("/life_journeys/#{@journey.id}", "/dashboard"),
        back: window.lpNavDirection("/dashboard", "/life_journeys/#{@journey.id}"),
        you: window.lpNavDirection("/dashboard", "/settings"),
        same: window.lpNavDirection("/dashboard", "/dashboard"),
        journey: window.lpNavDirection("/dashboard", "/life_points")
      })
    JS
    assert_equal "forward", dirs["forward"]
    assert_equal "back", dirs["back"]
    assert_nil dirs["you"]
    assert_nil dirs["same"]
    assert_nil dirs["journey"]
  end

  test "a failed visit clears direction and leaves the surface visible" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-nav", wait: 5

    within(".lp-dash-nav") { click_link "Mountain" }
    assert_selector "#strategy-world", wait: 5

    page.execute_script(<<~JS)
      document.documentElement.dataset.lpNav = "forward"
      document.dispatchEvent(new CustomEvent("turbo:fetch-request-error"))
    JS

    assert_no_selector "html[data-lp-nav]"
    assert_selector "#strategy-world", visible: true
    metrics = page.evaluate_script(<<~JS)
      (() => {
        const el = document.querySelector("#strategy-world")
        const r = el.getBoundingClientRect()
        const t = getComputedStyle(el).transform
        return { w: r.width, h: r.height, x: r.left, transform: t }
      })()
    JS
    assert_operator metrics["w"], :>=, 120
    assert_operator metrics["h"], :>=, 80
    assert_operator metrics["x"], :>=, 0
    assert_includes [ "none", "matrix(1, 0, 0, 1, 0, 0)" ], metrics["transform"]
  end

  test "reduced motion still reaches Today" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-nav", wait: 5

    page.driver.browser.execute_cdp(
      "Emulation.setEmulatedMedia",
      features: [ { name: "prefers-reduced-motion", value: "reduce" } ]
    )

    within(".lp-dash-nav") { click_link "Mountain" }
    assert_selector "#strategy-world", wait: 5
    within(".lp-dash-nav") { click_link "Today" }
    assert_selector ".lp-dash", wait: 5
    assert_no_selector "html[data-lp-nav]"
  end
end
