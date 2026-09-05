# frozen_string_literal: true

require "test_helper"

class V2OnboardingFlowTest < ActionDispatch::IntegrationTest
  test "two step flow finishes on mountain with seeded battle on today" do
    post registration_url, params: registration_params("fresh@example.com")
    assert_redirected_to v2_onboarding_path(step: "goal")

    follow_redirect!
    assert_response :success
    assert_match(/Name your mountain/i, response.body)
    assert_match(/Step 1 of 2/i, response.body)
    assert_select "#onboarding_goal[placeholder=?]", I18n.t("v2_onboarding.mountain_name_placeholder")

    user = User.find_by!(email_address: "fresh@example.com")
    assert_equal "fox", user.character
    assert user.character_chosen?

    patch v2_onboarding_url(step: "goal"), params: { onboarding: { goal: "Become a Ruby Developer" } }
    assert_redirected_to v2_onboarding_path(step: "camps")
    follow_redirect!
    assert_match(/Create your climb/i, response.body)
    assert_match(/Step 2 of 2/i, response.body)
    assert_select "[data-controller='onboarding-camps']"

    patch v2_onboarding_url(step: "camps"), params: {
      onboarding: {
        camp_titles: [ "Get certified", "Land first role" ]
      }
    }

    user.reload
    journey = user.primary_focused_journey
    first_project = user.strategy_goals.for_kind("project").order(:position).first
    assert_redirected_to life_journey_path(journey, open_camp: first_project.id)

    assert user.onboarding_completed?
    assert_equal "purpose", user.life_areas.v2_selected.first.key
    assert_equal "other", journey.setup_flag("onboarding_category")
    assert_equal "true", journey.setup_flag(Onboarding::Bootstrap::BOOTSTRAP_FLAG)
    assert_equal "easy", journey.commitment_key
    assert_nil journey.setup_flag("route")
    assert Strategy::HierarchyReady.call(user: user, journey: journey)
    assert user.daily_todos.where(scheduled_on: Date.current).exists?

    plan = user.strategy_goals.for_kind("plan").first
    assert_equal I18n.t("v2_onboarding.climb_plan_title"), plan.title
    assert_equal 2, plan.children.for_kind("project").count

    get life_journey_path(journey)
    assert_response :success
    assert_select ".lp-trail-destination", count: 0
    assert_select "[data-controller*='onboarding-mountain-tour']"

    get dashboard_path
    assert_response :success
    assert_match(/Take the first small step/i, response.body)
    assert_no_match(/Plan Your Route/i, response.body)
    assert_equal 0, user.habits.count
  end

  test "tracks onboarding step viewed and completed events" do
    post registration_url, params: registration_params("tracked@example.com")
    user = User.find_by!(email_address: "tracked@example.com")

    get v2_onboarding_path(step: "goal")
    assert_equal 1, user.user_events.named("onboarding_step_viewed").count

    patch v2_onboarding_url(step: "goal"), params: { onboarding: { goal: "Ship LifePoints" } }

    get v2_onboarding_path(step: "camps")
    viewed_steps = user.user_events.named("onboarding_step_viewed")
                       .order(:id)
                       .map { |event| event.properties["step"] }
    assert_equal %w[goal camps], viewed_steps

    patch v2_onboarding_url(step: "camps"), params: {
      onboarding: { camp_titles: [ "Launch" ] }
    }

    completed_steps = user.user_events.named("onboarding_step_completed")
                         .order(:id)
                         .map { |event| event.properties["step"] }
    assert_equal %w[goal camps], completed_steps
  end

  test "legacy session title migrates to goal for in-progress users" do
    post registration_url, params: registration_params("legacy-title@example.com")
    patch v2_onboarding_url(step: "mountain"), params: { onboarding: { title: "Finish the messy garage" } }
    assert_redirected_to v2_onboarding_path(step: "camps")

    get v2_onboarding_path(step: "goal")
    assert_response :success
    assert_select "#onboarding_goal[value=?]", "Finish the messy garage"
  end

  test "legacy steps redirect into the new flow" do
    post registration_url, params: registration_params("legacy-steps@example.com")

    get v2_onboarding_path(step: "welcome")
    assert_redirected_to v2_onboarding_path(step: "goal")

    get v2_onboarding_path(step: "character")
    assert_redirected_to v2_onboarding_path(step: "goal")

    patch v2_onboarding_url(step: "goal"), params: { onboarding: { goal: "Ship it" } }
    get v2_onboarding_path(step: "battles")
    assert_redirected_to v2_onboarding_path(step: "camps")
  end

  test "camps step requires at least one camp" do
    post registration_url, params: registration_params("need-camps@example.com")
    patch v2_onboarding_url(step: "goal"), params: { onboarding: { goal: "Ship LifePoints" } }

    patch v2_onboarding_url(step: "camps"), params: { onboarding: { camp_titles: [ "" ] } }

    assert_redirected_to v2_onboarding_path(step: "camps")
    follow_redirect!
    assert_select ".lp-flash--alert", text: /camp/i

    user = User.find_by!(email_address: "need-camps@example.com")
    refute user.onboarding_completed?
    assert_equal 0, user.life_journeys.count
  end

  test "camps step redirects to goal when goal is missing from session" do
    post registration_url, params: registration_params("missing-goal@example.com")

    patch v2_onboarding_url(step: "camps"), params: {
      onboarding: { camp_titles: [ "Launch" ] }
    }

    assert_redirected_to v2_onboarding_path(step: "goal")
  end

  test "bootstrap failure returns to camps with alert and leaves no spine" do
    post registration_url, params: registration_params("bootstrap-fail@example.com")
    patch v2_onboarding_url(step: "goal"), params: { onboarding: { goal: "Ship LifePoints" } }

    original_bootstrap = Onboarding::Bootstrap.method(:call)
    Onboarding::Bootstrap.define_singleton_method(:call) do |**|
      raise Onboarding::Bootstrap::Error, "Could not save your climb."
    end
    begin
      patch v2_onboarding_url(step: "camps"), params: {
        onboarding: { camp_titles: [ "Launch" ] }
      }
    ensure
      Onboarding::Bootstrap.define_singleton_method(:call, original_bootstrap)
    end

    assert_redirected_to v2_onboarding_path(step: "camps")
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

  test "registration assigns fox companion before onboarding" do
    post registration_url, params: registration_params("fox-climber@example.com")

    user = User.find_by!(email_address: "fox-climber@example.com")
    assert_equal "fox", user.character
    assert user.companion_pick_done?

    finish_onboarding_draft!(goal: "Lead with calm", camps: [ "Build trust", "Grow skills" ])

    journey = user.reload.primary_focused_journey
    get life_journey_path(journey)
    assert_response :success
    assert_select ".lp-trail-hud__avatar img[src*='fox']"
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

  def finish_onboarding_draft!(goal:, camps:)
    patch v2_onboarding_url(step: "goal"), params: { onboarding: { goal: goal } }
    patch v2_onboarding_url(step: "camps"), params: { onboarding: { camp_titles: camps } }
  end
end
