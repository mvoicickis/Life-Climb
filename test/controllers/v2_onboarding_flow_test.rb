# frozen_string_literal: true

require "test_helper"

class V2OnboardingFlowTest < ActionDispatch::IntegrationTest
  test "two step flow finishes on mountain with seeded battle on today" do
    post registration_url, params: registration_params("fresh@example.com")
    assert_redirected_to v2_onboarding_path(step: "intro_big_goals")

    follow_redirect!
    advance_through_intros!
    follow_redirect!
    assert_response :success
    assert_match(/What is your goal\?/i, response.body)
    assert_match(/Step 1 of 3/i, response.body)
    assert_select "#onboarding_goal[placeholder=?]", I18n.t("v2_onboarding.goal_placeholder")

    user = User.find_by!(email_address: "fresh@example.com")
    assert_equal "fox", user.character
    assert user.character_chosen?

    patch v2_onboarding_url(step: "goal"), params: { onboarding: { goal: "Become a Ruby Developer" } }
    assert_redirected_to v2_onboarding_path(step: "camps")
    follow_redirect!
    assert_match(/What steps do you need to get to/i, response.body)
    assert_match(/Step 2 of 3/i, response.body)
    assert_select "[data-controller='onboarding-camps']"

    patch v2_onboarding_url(step: "camps"), params: {
      onboarding: {
        camp_titles: [ "Get certified", "Land first role" ]
      }
    }
    assert_redirected_to v2_onboarding_path(step: "climb")

    user.reload
    journey = user.primary_focused_journey
    refute user.onboarding_completed?

    patch v2_onboarding_url(step: "climb")
    assert_redirected_to life_journey_path(journey)

    user.reload
    first_project = user.strategy_goals.for_kind("project").order(:position).first
    assert user.onboarding_completed?
    assert_equal "self", user.life_areas.v2_selected.first.key
    assert_equal "other", journey.setup_flag("onboarding_category")
    assert_equal "true", journey.setup_flag(Onboarding::Bootstrap::BOOTSTRAP_FLAG)
    assert_equal "pending", journey.setup_flag(Onboarding::Bootstrap::FIRST_CAMP_REVEAL_FLAG)
    assert_equal "easy", journey.commitment_key
    assert_equal 0, journey.commitment_habit_count
    assert_equal 1, journey.commitment_battle_count
    assert_nil journey.setup_flag("route")
    refute Strategy::HierarchyReady.call(user: user, journey: journey)
    refute user.daily_todos.where(scheduled_on: Date.current).exists?

    gap = Today::Commitment.setup_gap(user: user, journey: journey)
    refute_equal :habits, gap&.kind
    assert_equal :battles, gap&.kind

    plan = user.strategy_goals.for_kind("plan").first
    assert_equal I18n.t("v2_onboarding.climb_plan_title"), plan.title
    assert_equal 2, plan.children.for_kind("project").count

    get life_journey_path(journey)
    assert_response :success
    assert_select ".lp-trail-destination", count: 0
    assert_select "#companion-pick-prompt", count: 0
    assert_select ".lp-trail.is-first-camp-reveal"
    assert_select "#trail-camp-#{first_project.id}[data-camp-title=?]", "Get certified"
    assert_select "[data-first-camp-reveal-camp-title-value=?]", "Get certified"
    assert_select "[data-first-camp-reveal-camps-value]"
    assert_select ".lp-first-camp-reveal__skip", text: I18n.t("strategy.rpg.trail.first_camp_reveal.skip_hint")
    assert_select ".lp-trail-sheet.is-open", count: 0
    assert_select "#trail-sheet-title", text: "Get certified", count: 1
    assert_select ".lp-first-camp-setup__title", count: 0
    assert_select ".lp-trail.is-first-camp-reveal .lp-trail-sheet__menu-btn", count: 0
    assert_select ".lp-trail.is-first-camp-reveal .lp-trail-sheet__close", count: 0
    assert_select "input[type=submit][value=?]", I18n.t("strategy.rpg.trail.first_camp_reveal.submit")
    assert_select ".lp-first-camp-setup .lp-trail-camp-idle.lp-frost"
    assert_select ".lp-first-camp-setup__hint", count: 0
    assert_select "[data-action*='first-camp-battle#titleKeydown']"

    get dashboard_path
    assert_response :success
    assert_no_match(/Take the first small step/i, response.body)
    assert_no_match(/Plan Your Route/i, response.body)
    pill_label = I18n.t("dash.battlefield.empty_cta.add_todays_battle")
    assert_select "#today-battlefield-body a.lp-today-empty-cta__pill", text: pill_label, count: 1
    href = assert_select("#today-battlefield-body a.lp-today-empty-cta__pill").first["href"]
    query = Rack::Utils.parse_query(URI.parse(href).query)
    assert_equal "1", query["first_camp_setup"]
    assert_equal 0, user.habits.count
  end

  test "duplicate camps patch redirects to same journey without error" do
    post registration_url, params: registration_params("double-camps@example.com")
    patch v2_onboarding_url(step: "goal"), params: { onboarding: { goal: "Become a Ruby Developer" } }

    camps_params = {
      onboarding: {
        goal: "Become a Ruby Developer",
        camp_titles: [ "Get certified", "Land first role" ]
      }
    }

    patch v2_onboarding_url(step: "camps"), params: camps_params
    user = User.find_by!(email_address: "double-camps@example.com")
    user.reload
    journey = user.primary_focused_journey
    assert_redirected_to v2_onboarding_path(step: "climb")

    patch v2_onboarding_url(step: "camps"), params: camps_params
    user.reload
    assert_redirected_to v2_onboarding_path(step: "climb")
    assert_equal 1, user.life_journeys.count

    patch v2_onboarding_url(step: "climb")
    user.reload
    assert_redirected_to life_journey_path(journey)
    assert user.onboarding_completed?
    assert_equal 1, user.life_journeys.count
    assert_equal 1, user.life_areas.where(dream_id: nil, key: "self").count
  end

  test "tracks onboarding step viewed and completed events" do
    post registration_url, params: registration_params("tracked@example.com")
    user = User.find_by!(email_address: "tracked@example.com")

    follow_redirect!
    advance_through_intros!
    follow_redirect!

    viewed_steps = user.user_events.named("onboarding_step_viewed")
                       .order(:id)
                       .map { |event| event.properties["step"] }
    assert_equal %w[intro_big_goals intro_battles goal], viewed_steps

    patch v2_onboarding_url(step: "goal"), params: { onboarding: { goal: "Ship LifePoints" } }

    get v2_onboarding_path(step: "camps")
    viewed_steps = user.user_events.named("onboarding_step_viewed")
                       .order(:id)
                       .map { |event| event.properties["step"] }
    assert_equal %w[intro_big_goals intro_battles goal camps], viewed_steps

    patch v2_onboarding_url(step: "camps"), params: {
      onboarding: { camp_titles: [ "Launch" ] }
    }
    follow_redirect!
    get v2_onboarding_path(step: "climb")
    viewed_steps = user.user_events.named("onboarding_step_viewed")
                       .order(:id)
                       .map { |event| event.properties["step"] }
    assert_includes viewed_steps, "climb"

    patch v2_onboarding_url(step: "climb")

    completed_steps = user.user_events.named("onboarding_step_completed")
                         .order(:id)
                         .map { |event| event.properties["step"] }
    assert_equal %w[intro_big_goals intro_battles goal camps climb], completed_steps
    refute user.user_events.named("onboarding_step_completed").any? { |e| e.properties["skipped"] }
  end

  test "plain signup lands on intro one" do
    post registration_url, params: registration_params("intro-signup@example.com")
    assert_redirected_to v2_onboarding_path(step: "intro_big_goals")
    follow_redirect!
    assert_match(I18n.t("v2_onboarding.intro_big_goals_title"), response.body)
  end

  test "intro skip tracks skipped and lands on goal" do
    post registration_url, params: registration_params("intro-skip@example.com")
    user = User.find_by!(email_address: "intro-skip@example.com")

    follow_redirect!
    patch v2_onboarding_url(step: "intro_big_goals"), params: { onboarding: { skip: true } }
    assert_redirected_to v2_onboarding_path(step: "goal")

    event = user.user_events.named("onboarding_step_completed").order(:id).last
    assert_equal "intro_big_goals", event.properties["step"]
    assert event.properties["skipped"]

    follow_redirect!
    assert_match(/What is your goal\?/i, response.body)
  end

  test "in-flight user with goal in session lands on goal not intro" do
    post registration_url, params: registration_params("inflight@example.com")
    patch v2_onboarding_url(step: "goal"), params: { onboarding: { goal: "Learn piano" } }
    assert_redirected_to v2_onboarding_path(step: "camps")

    get v2_onboarding_path(step: "intro_big_goals")
    assert_redirected_to v2_onboarding_path(step: "goal")
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
    assert_redirected_to v2_onboarding_path(step: "intro_big_goals")

    get v2_onboarding_path(step: "character")
    assert_redirected_to v2_onboarding_path(step: "intro_big_goals")

    patch v2_onboarding_url(step: "goal"), params: { onboarding: { goal: "Ship it" } }
    get v2_onboarding_path(step: "battles")
    assert_redirected_to v2_onboarding_path(step: "camps")
  end

  # Typed-but-not-added camp submit is covered by V2OnboardingCampsTypedSubmitTest (system).
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

  test "bootstrap spine without completed onboarding resumes at climb in a new session" do
    user = User.create!(
      name: "Resume",
      email_address: "resume-climb-#{SecureRandom.hex(4)}@example.com",
      password: "password12345",
      password_confirmation: "password12345",
      character: "fox"
    )
    Onboarding::Bootstrap.call(
      user: user,
      goal_title: "Learn piano",
      camp_titles: [ "Buy keyboard", "Practice scales" ],
      complete_onboarding: false
    )
    refute user.reload.onboarding_completed?

    sign_in_as user
    get v2_onboarding_path
    assert_response :success
    assert_select "[data-controller='onboarding-climb']"
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

    get settings_path
    assert_response :success
    assert_equal "fox", user.reload.character
    assert_select ".lp-you__avatar-initial", text: "A"
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

  def advance_through_intros!
    patch v2_onboarding_url(step: "intro_big_goals")
    assert_redirected_to v2_onboarding_path(step: "intro_battles")
    follow_redirect!
    patch v2_onboarding_url(step: "intro_battles")
    assert_redirected_to v2_onboarding_path(step: "goal")
  end

  def finish_onboarding_draft!(goal:, camps:)
    follow_redirect! if response.redirect?
    if response.body.include?(I18n.t("v2_onboarding.intro_big_goals_title"))
      advance_through_intros!
      follow_redirect!
    end
    patch v2_onboarding_url(step: "goal"), params: { onboarding: { goal: goal } }
    patch v2_onboarding_url(step: "camps"), params: { onboarding: { camp_titles: camps } }
    patch v2_onboarding_url(step: "climb")
  end
end
