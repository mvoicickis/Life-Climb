# frozen_string_literal: true

require "test_helper"

class OnboardingBootstrapTest < ActiveSupport::TestCase
  include MountainTrailHelper

  setup do
    @user = User.create!(
      name: "Alex",
      email_address: "bootstrap-#{SecureRandom.hex(4)}@example.com",
      password: "password12345",
      password_confirmation: "password12345"
    )
  end

  test "creates goal one plan multiple projects first battle and marks onboarding complete" do
    result = Onboarding::Bootstrap.call(
      user: @user,
      goal_title: "Become a Ruby Developer",
      camp_titles: [ "Get certified", "Land first role" ]
    )

    @user.reload
    journey = result.journey

    assert @user.onboarding_completed?
    assert_equal "purpose", journey.life_area.key
    assert_equal "other", journey.setup_flag("onboarding_category")
    assert_equal "true", journey.setup_flag(Onboarding::Bootstrap::BOOTSTRAP_FLAG)
    assert_equal "easy", journey.commitment_key
    assert_equal 0, journey.commitment_habit_count
    assert_equal 1, journey.commitment_battle_count
    assert_nil journey.setup_flag("route")

    assert_equal "Become a Ruby Developer", result.goal.title
    assert_equal I18n.t("v2_onboarding.climb_plan_title"), result.plan.title
    assert_equal 2, result.projects.size
    assert_equal "Get certified", result.projects[0].title
    assert_equal "Land first role", result.projects[1].title
    assert_equal 0, result.projects[0].position
    assert_equal 1, result.projects[1].position

    assert_equal 1, result.projects[0].children.for_kind("day").count
    assert_equal Date.current, result.first_battle.scheduled_on
    assert_equal I18n.t("strategy.rpg.trail.battle_suggestions").first, result.first_battle.title
    assert_equal 0, result.projects[1].children.for_kind("day").count

    trail = Strategy::Trail.for(plan: result.plan.reload)
    assert_equal 2, trail.nodes.size
    assert_equal :current, trail.nodes[0].state
    assert_equal :locked, trail.nodes[1].state
    assert_equal result.projects[0].id, trail.current_node.id

    first_slot = MountainTrailHelper::AutoSlot.call(index: 1, total: 2)
    last_slot = MountainTrailHelper::AutoSlot.call(index: 0, total: 2)
    assert_in_delta first_slot[:trail_y], result.projects[0].trail_y, 0.0001
    assert_in_delta last_slot[:trail_y], result.projects[1].trail_y, 0.0001
    assert_operator result.projects[0].trail_y.to_f, :>, result.projects[1].trail_y.to_f

    marker = mountain_trail_climber_marker(result.projects, user: @user)
    assert marker[:visible]
    assert_operator marker[:y], :>, result.projects[0].trail_y.to_f

    assert Strategy::HierarchyReady.call(user: @user, journey: journey)
    assert @user.daily_todos.where(scheduled_on: Date.current).exists?
    assert_equal 0, @user.habits.count
  end

  test "rejects empty camps" do
    error = assert_raises(Onboarding::Bootstrap::Error) do
      Onboarding::Bootstrap.call(
        user: @user,
        goal_title: "Ship it",
        camp_titles: []
      )
    end

    assert_equal I18n.t("v2_onboarding.need_camp"), error.message
    refute @user.reload.onboarding_completed?
    assert_equal 0, @user.life_journeys.count
  end

  test "rejects empty goal" do
    error = assert_raises(Onboarding::Bootstrap::Error) do
      Onboarding::Bootstrap.call(
        user: @user,
        goal_title: "",
        camp_titles: [ "Build" ]
      )
    end

    assert_equal I18n.t("v2_onboarding.need_goal"), error.message
    refute @user.reload.onboarding_completed?
    assert_equal 0, @user.life_journeys.count
  end
end
