# frozen_string_literal: true

require "test_helper"

class V2OnboardingFlowTest < ActionDispatch::IntegrationTest
  test "four step flow finishes on mountain with battles on today" do
    post registration_url, params: registration_params("fresh@example.com")
    assert_redirected_to v2_onboarding_path(step: "character")

    follow_redirect!
    assert_response :success
    assert_match(/Choose your companion/i, response.body)
    assert_match(/Step 1 of 4/i, response.body)
    assert_select "input[name='user[character]'][value=fox]"

    patch v2_onboarding_url(step: "character"), params: { user: { character: "fox" } }
    assert_redirected_to v2_onboarding_path(step: "goal")
    follow_redirect!
    assert_match(/What is your goal/i, response.body)
    assert_match(/Step 2 of 4/i, response.body)
    assert_select "#onboarding_goal[placeholder=?]", I18n.t("v2_onboarding.goal_placeholder")
    assert_select ".lp-adventure__examples-note-label", text: I18n.t("v2_onboarding.goal_examples_label")

    patch v2_onboarding_url(step: "goal"), params: { onboarding: { goal: "Become a Ruby Developer" } }
    assert_redirected_to v2_onboarding_path(step: "camp")
    follow_redirect!
    assert_match(/make a camp to get you there/i, response.body)
    assert_match(/Camps are the stops along the way/i, response.body)

    patch v2_onboarding_url(step: "camp"), params: { onboarding: { camp: "Get certified" } }
    assert_redirected_to v2_onboarding_path(step: "battles")
    follow_redirect!
    assert_match(/What are today/i, response.body)
    assert_select "[data-controller='onboarding-battles']"

    patch v2_onboarding_url(step: "battles"), params: {
      onboarding: {
        battle_titles: [ "Study chapter 1 for 20 minutes" ],
        basic_title: "Drink water"
      }
    }

    user = User.find_by!(email_address: "fresh@example.com")
    journey = user.primary_focused_journey
    assert_redirected_to life_journey_path(journey)

    assert user.onboarding_completed?
    assert_equal "purpose", user.life_areas.v2_selected.first.key
    assert_equal "other", journey.setup_flag("onboarding_category")
    assert_equal "true", journey.setup_flag(Onboarding::Bootstrap::BOOTSTRAP_FLAG)
    assert_equal "easy", journey.commitment_key
    assert_nil journey.setup_flag("route")
    assert Strategy::HierarchyReady.call(user: user, journey: journey)
    assert user.daily_todos.where(scheduled_on: Date.current).exists?

    get life_journey_path(journey)
    assert_response :success
    assert_select ".lp-trail-destination", count: 0
    assert_select "[data-controller*='onboarding-mountain-tour']"

    get dashboard_path
    assert_response :success
    assert_match(/Study chapter 1 for 20 minutes/i, response.body)
    assert_match(/Drink water/i, response.body)
    assert_no_match(/Plan Your Route/i, response.body)
  end

  test "legacy session title migrates to goal for in-progress users" do
    post registration_url, params: registration_params("legacy-title@example.com")
    patch v2_onboarding_url(step: "character"), params: { user: { character: "birdie" } }
    patch v2_onboarding_url(step: "mountain"), params: { onboarding: { title: "Finish the messy garage" } }
    assert_redirected_to v2_onboarding_path(step: "camp")

    get v2_onboarding_path(step: "goal")
    assert_response :success
    assert_select "#onboarding_goal[value=?]", "Finish the messy garage"
  end

  test "legacy steps redirect into the new flow" do
    post registration_url, params: registration_params("legacy-steps@example.com")

    get v2_onboarding_path(step: "welcome")
    assert_redirected_to v2_onboarding_path(step: "character")

    patch v2_onboarding_url(step: "character"), params: { user: { character: "fox" } }
    get v2_onboarding_path(step: "mountain")
    assert_redirected_to v2_onboarding_path(step: "goal")
  end

  test "battles step requires basic title" do
    post registration_url, params: registration_params("need-basic@example.com")
    patch v2_onboarding_url(step: "character"), params: { user: { character: "fox" } }
    patch v2_onboarding_url(step: "goal"), params: { onboarding: { goal: "Ship LifePoints" } }
    patch v2_onboarding_url(step: "camp"), params: { onboarding: { camp: "Launch" } }

    patch v2_onboarding_url(step: "battles"), params: {
      onboarding: { battle_titles: [ "Write one test" ], basic_title: "" }
    }

    assert_redirected_to v2_onboarding_path(step: "battles")
    follow_redirect!
    assert_match(I18n.t("v2_onboarding.need_basic"), response.body)

    user = User.find_by!(email_address: "need-basic@example.com")
    refute user.onboarding_completed?
    assert_equal 0, user.habits.count
  end

  test "bootstrap failure returns to battles with alert and leaves no spine" do
    post registration_url, params: registration_params("bootstrap-fail@example.com")
    patch v2_onboarding_url(step: "character"), params: { user: { character: "fox" } }
    patch v2_onboarding_url(step: "goal"), params: { onboarding: { goal: "Ship LifePoints" } }
    patch v2_onboarding_url(step: "camp"), params: { onboarding: { camp: "Launch" } }

    original_bootstrap = Onboarding::Bootstrap.method(:call)
    Onboarding::Bootstrap.define_singleton_method(:call) do |**|
      raise Onboarding::Bootstrap::Error, "Could not save your climb."
    end
    begin
      patch v2_onboarding_url(step: "battles"), params: {
        onboarding: {
          battle_titles: [ "Write one test" ],
          basic_title: "Stretch"
        }
      }
    ensure
      Onboarding::Bootstrap.define_singleton_method(:call, original_bootstrap)
    end

    assert_redirected_to v2_onboarding_path(step: "battles")
    follow_redirect!
    assert_match(/Could not save your climb/i, response.body)

    user = User.find_by!(email_address: "bootstrap-fail@example.com")
    refute user.onboarding_completed?
    assert_equal 0, user.life_journeys.count
    assert_equal 0, user.strategy_goals.count
  end

  test "completed users are redirected away from onboarding" do
    user = users(:one)
    seed_climb!(user)
    sign_in_as user

    get v2_onboarding_path(step: "goal")
    assert_redirected_to life_journey_path(user.primary_focused_journey)
  end

  test "picking birdie during onboarding shows companion avatar on mountain" do
    post registration_url, params: registration_params("birdie-climber@example.com")
    patch v2_onboarding_url(step: "character"), params: { user: { character: "birdie" } }
    finish_onboarding_draft!(goal: "Lead with calm", camp: "Build trust", battles: [ "Call one friend" ])

    user = User.find_by!(email_address: "birdie-climber@example.com")
    journey = user.primary_focused_journey

    get life_journey_path(journey)
    assert_response :success
    assert_select ".lp-trail-hud__avatar img[src*='birdie']"
  end

  private

  def registration_params(email)
    {
      user: {
        name: "Alex",
        email_address: email,
        password: "password12345",
        password_confirmation: "password12345"
      }
    }
  end

  def finish_onboarding_draft!(goal:, camp:, battles: [ "Take the first small step" ], basic: "Drink water")
    patch v2_onboarding_url(step: "goal"), params: { onboarding: { goal: goal } }
    patch v2_onboarding_url(step: "camp"), params: { onboarding: { camp: camp } }
    patch v2_onboarding_url(step: "battles"), params: {
      onboarding: { battle_titles: battles, basic_title: basic }
    }
  end
end
