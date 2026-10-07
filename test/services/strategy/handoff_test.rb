# frozen_string_literal: true

require "test_helper"

class StrategyHandoffTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Ship LifePoints",
      ideal_scene: "App in production",
      current_reality: "Still building",
      next_win: "Launch Beta",
      today_mission: "Write one test",
      closer_percent: 20
    )
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
  end

  test "empty strategy points at locking the goal" do
    handoff = Strategy::Handoff.for(user: @user, journey: @journey)
    assert_match(/Lock your season goal/i, handoff[:label])
  end

  test "project handoff names the plan" do
    goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Become debt-free", position: 0
    )
    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: goal, horizon: "plan", title: "Find a job", position: 0
    )
    handoff = Strategy::Handoff.for(user: @user, journey: @journey)
    assert_match(/Add a camp under “Find a job”/i, handoff[:label])
    assert_includes handoff[:href], "focus_id=#{plan.id}"
  end

  test "handoff focuses the same path Project PathProject would resolve" do
    goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Become debt-free", position: 0
    )
    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: goal, horizon: "plan", title: "Find a job", position: 0
    )
    first = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project",
      title: "First camp", position: 0
    )
    second = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project",
      title: "Second camp", position: 1
    )
    first.children.create!(
      user: @user, life_area: @area, life_journey: @journey, horizon: "day",
      title: "First camp battle", scheduled_on: Date.current, position: 0
    )
    day = second.children.create!(
      user: @user, life_area: @area, life_journey: @journey, horizon: "day",
      title: "Touch second", scheduled_on: Date.current, position: 0
    )
    day.update_columns(updated_at: 1.minute.from_now)

    resolved = Strategy::PathProject.resolve(user: @user, journey: @journey)
    assert_equal first, resolved

    handoff = Strategy::Handoff.for(user: @user, journey: @journey)
    assert_match(/Continue on Mountain/i, handoff[:label])
    assert_includes handoff[:href], "focus_id=#{first.id}"
  end

  test "add_battle names the resolved empty path Project" do
    goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Become debt-free", position: 0
    )
    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: goal, horizon: "plan", title: "Find a job", position: 0
    )
    project = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project",
      title: "Auth", position: 0
    )

    assert_equal project, Strategy::PathProject.resolve(user: @user, journey: @journey)
    handoff = Strategy::Handoff.for(user: @user, journey: @journey)
    assert_match(/Add today’s battle under “Auth”/i, handoff[:label])
    assert_includes handoff[:href], "focus_id=#{project.id}"
  end

  test "summit reached points at choose next goal" do
    user = User.create!(
      name: "Summit handoff",
      email_address: "summit-handoff-#{SecureRandom.hex(4)}@example.com",
      password: "password12345",
      password_confirmation: "password12345",
      planning_version: 2,
      onboarding_completed_at: Time.current
    )
    bootstrap = Onboarding::Bootstrap.call(
      user: user,
      goal_title: "Peak goal",
      camp_titles: [ "Camp one" ]
    )
    journey = bootstrap.journey
    camp = bootstrap.projects.first
    camp.children.for_kind("day").find_each { |b| b.update!(completed_at: Time.current) }
    camp.complete!

    handoff = Strategy::Handoff.for(user: user, journey: journey)
    assert_equal :summit_next_goal, handoff[:step]
    assert_equal I18n.t("dash.battlefield.empty_cta.summit_next_goal"), handoff[:label]
    assert_includes handoff[:href], "/summit_next_goal"
  end

  test "open_strategy when nested battles exist under path Project" do
    goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Become debt-free", position: 0
    )
    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: goal, horizon: "plan", title: "Find a job", position: 0
    )
    project = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project",
      title: "Auth", position: 0
    )
    leaf = project
    leaf.children.create!(
      user: @user, life_area: @area, life_journey: @journey, horizon: "day",
      title: "Nested fight", scheduled_on: Date.current, position: 0
    )

    assert project.children.for_kind("day").any?
    assert Strategy::Progress.battles_under(project).any?

    handoff = Strategy::Handoff.for(user: @user, journey: @journey)
    assert_match(/Continue on Mountain/i, handoff[:label])
    refute_match(/Add today’s battle/i, handoff[:label])
  end
end
