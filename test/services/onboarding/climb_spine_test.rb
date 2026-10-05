# frozen_string_literal: true

require "test_helper"

class OnboardingClimbSpineTest < ActiveSupport::TestCase
  include MountainTrailHelper

  setup do
    @user = User.create!(
      name: "Alex",
      email_address: "climb-spine-#{SecureRandom.hex(4)}@example.com",
      password: "password12345",
      password_confirmation: "password12345"
    )
  end

  test "creates same spine records as bootstrap without marking onboarding complete" do
    result = nil
    assert_no_changes -> { @user.reload.onboarding_completed_at } do
      result = Onboarding::ClimbSpine.call(
        user: @user,
        goal_title: "Become a Ruby Developer",
        camp_titles: [ "Get certified", "Land first role" ]
      )
    end

    refute @user.reload.onboarding_completed?

    journey = result.journey

    assert_equal "purpose", journey.life_area.key
    assert_equal "other", journey.setup_flag("onboarding_category")
    assert_equal "true", journey.setup_flag(Onboarding::Bootstrap::BOOTSTRAP_FLAG)
    assert_equal "pending", journey.setup_flag(Onboarding::Bootstrap::FIRST_CAMP_REVEAL_FLAG)
    assert_equal result.projects[0].id, journey.setup_flag(Onboarding::Bootstrap::FIRST_CAMP_ID_FLAG).to_i
    assert_equal "easy", journey.commitment_key
    assert_equal 0, journey.commitment_habit_count
    assert_equal 1, journey.commitment_battle_count

    assert_equal "Become a Ruby Developer", result.goal.title
    assert_equal I18n.t("v2_onboarding.climb_plan_title"), result.plan.title
    assert_equal 2, result.projects.size
    assert_equal "Get certified", result.projects[0].title
    assert_equal "Land first role", result.projects[1].title

    assert_equal 1, result.projects[0].children.for_kind("day").count
    assert_equal Date.current, result.first_battle.scheduled_on
    assert_equal I18n.t("strategy.rpg.trail.battle_suggestions").first, result.first_battle.title

    trail = Strategy::Trail.for(plan: result.plan.reload)
    assert_equal result.projects[0].id, trail.current_node.id

    assert Strategy::HierarchyReady.call(user: @user, journey: journey)
    assert @user.daily_todos.where(scheduled_on: Date.current).exists?
  end

  test "bootstrap wraps climb spine with onboarding completion and matches spine snapshot" do
    camp_titles = [ "Get certified", "Land first role" ]
    goal_title = "Become a Ruby Developer"

    spine_user = User.create!(
      name: "Spine",
      email_address: "climb-spine-only-#{SecureRandom.hex(4)}@example.com",
      password: "password12345",
      password_confirmation: "password12345"
    )
    spine_only = Onboarding::ClimbSpine.call(user: spine_user, goal_title: goal_title, camp_titles: camp_titles)
    spine_snapshot = spine_structure_snapshot(spine_only)

    bootstrap_user = User.create!(
      name: "Bob",
      email_address: "bootstrap-parity-#{SecureRandom.hex(4)}@example.com",
      password: "password12345",
      password_confirmation: "password12345"
    )
    bootstrap = Onboarding::Bootstrap.call(user: bootstrap_user, goal_title: goal_title, camp_titles: camp_titles)

    assert bootstrap_user.reload.onboarding_completed?
    refute spine_user.reload.onboarding_completed?
    assert_equal spine_snapshot, spine_structure_snapshot(bootstrap)
  end

  test "seed_battle false skips battle and daily todos" do
    area = LifeAreas::Select.call(user: @user, keys: [ Onboarding::Bootstrap::DEFAULT_AREA_KEY ]).first
    result = Onboarding::ClimbSpine.call(
      user: @user,
      goal_title: "No seed",
      camp_titles: [ "Camp" ],
      life_area: area,
      seed_battle: false,
      celebrate_goal: false,
      include_bootstrap_flag: false,
      first_camp_reveal_status: "done"
    )

    assert_nil result.first_battle
    assert_equal 0, result.projects.first.children.for_kind("day").count
    assert_equal 0, @user.daily_todos.where(scheduled_on: Date.current).count
    assert_equal "done", result.journey.setup_flag(Onboarding::Bootstrap::FIRST_CAMP_REVEAL_FLAG)
  end

  test "rejects empty camps" do
    error = assert_raises(Onboarding::ClimbSpine::Error) do
      Onboarding::ClimbSpine.call(user: @user, goal_title: "Ship it", camp_titles: [])
    end

    assert_equal I18n.t("v2_onboarding.need_camp"), error.message
    assert_equal 0, @user.life_journeys.count
  end

  private

  def spine_structure_snapshot(result)
    {
      goal_title: result.goal.title,
      plan_title: result.plan.title,
      project_titles: result.projects.map(&:title),
      project_positions: result.projects.map(&:position),
      project_stages: result.projects.map(&:stage),
      project_trail_y: result.projects.map { |p| p.trail_y.to_f.round(4) },
      battle_title: result.first_battle.title,
      battle_scheduled_on: result.first_battle.scheduled_on,
      commitment_key: result.journey.commitment_key,
      bootstrap_flag: result.journey.setup_flag(Onboarding::Bootstrap::BOOTSTRAP_FLAG),
      reveal_flag: result.journey.setup_flag(Onboarding::Bootstrap::FIRST_CAMP_REVEAL_FLAG),
      first_camp_id_matches_first_project:
        result.journey.setup_flag(Onboarding::Bootstrap::FIRST_CAMP_ID_FLAG).to_i == result.projects.first.id,
      daily_todos_today: result.journey.user.daily_todos.where(scheduled_on: Date.current).count
    }
  end
end
