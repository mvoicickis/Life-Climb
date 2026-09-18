# frozen_string_literal: true

require "application_system_test_case"

class CampArrangeAddTest < ApplicationSystemTestCase
  def setup_user_with_camps!(email:, camps:)
    user = User.create!(
      name: "Alex",
      email_address: email,
      password: "password12345",
      planning_version: 2
    )
    allow_extra_climbs!(user)
    Onboarding::Bootstrap.call(user: user, goal_title: "Climb goal", camp_titles: camps)
    user.primary_focused_journey.clear_first_camp_reveal!
    user.update!(
      support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ],
      character: "fox",
      mountain_trail_tour_ack: 7
    )
    user
  end

  def sign_in_and_visit_mountain!(user)
    journey = user.primary_focused_journey
    plan = user.strategy_goals.for_kind("plan").not_holding.first
    goal = plan.root_goal

    visit new_session_path
    fill_in "Email", with: user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-nav", wait: 8
    visit life_journey_path(journey, goal_id: goal.id, plan_id: plan.id)
    assert_selector "#mountain-trail", wait: 10
  end

  def open_arrange_overlay!
    plaque = find(".lp-trail__goal-plaque", visible: :all)
    page.execute_script("arguments[0].click()", plaque.native)
    assert_selector ".lp-trail__goal-menu:not([hidden])", wait: 3
    click_button "Change camp order"
    assert_selector "#trail-arrange-camps:not([hidden])", wait: 5
    assert page.evaluate_script("document.body.classList.contains('is-arrange-open')")
  end

  setup do
    page.driver.browser.manage.window.resize_to(360, 800)
  end

  test "add camp opens plant sheet above arrange and creates camp on success" do
    user = setup_user_with_camps!(
      email: "camp-plant-add@example.com",
      camps: [ "Alpha", "Beta", "Gamma" ]
    )
    plan = user.strategy_goals.for_kind("plan").not_holding.first
    before = plan.children.for_kind("project").count

    sign_in_and_visit_mountain!(user)
    open_arrange_overlay!

    click_button "+ Add a camp"
    assert_selector ".lp-trail-plant.is-open", wait: 3
    assert page.evaluate_script("document.body.classList.contains('is-arrange-open')")

    within(".lp-trail-plant.is-open") do
      fill_in placeholder: /What do you want to get better at/i, with: "Delta camp"
      find(".lp-trail-plant__submit").click
    end

    assert_no_selector ".lp-trail-plant.is-open", wait: 10
    camp = plan.reload.children.for_kind("project").find_by!(title: "Delta camp")
    assert_equal before + 1, plan.children.for_kind("project").count
    assert_selector "#trail-camp-#{camp.id}", wait: 8
    assert page.evaluate_script("document.getElementById('trail-arrange-camps').hidden")
    assert_not page.evaluate_script("document.body.classList.contains('is-arrange-open')")
  end

  test "escape closes plant first while arrange stays open" do
    user = setup_user_with_camps!(
      email: "camp-plant-esc@example.com",
      camps: [ "One", "Two" ]
    )
    plan = user.strategy_goals.for_kind("plan").not_holding.first
    before = plan.children.for_kind("project").count

    sign_in_and_visit_mountain!(user)
    open_arrange_overlay!
    click_button "+ Add a camp"
    assert_selector ".lp-trail-plant.is-open", wait: 3

    fill_in placeholder: /What do you want to get better at/i, with: "Ghost camp"
    find("body").send_keys(:escape)

    assert_no_selector ".lp-trail-plant.is-open", wait: 3
    assert_selector "#trail-arrange-camps:not([hidden])"
    assert_equal before, plan.reload.children.for_kind("project").count
  end
end
