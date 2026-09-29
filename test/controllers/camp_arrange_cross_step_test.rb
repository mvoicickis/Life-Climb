# frozen_string_literal: true

require "test_helper"

class CampArrangeCrossStepTest < ActionDispatch::IntegrationTest
  def finish_onboarding!(email:, camps:)
    post registration_url, params: {
      user: {
        name: "Alex",
        email_address: email,
        password: "password12345",
        password_confirmation: "password12345"
      }
    }
    follow_redirect!
    patch v2_onboarding_url(step: "goal"), params: { onboarding: { goal: "Summit goal" } }
    patch v2_onboarding_url(step: "camps"), params: { onboarding: { camp_titles: camps } }
    follow_redirect!
    user = User.find_by!(email_address: email)
    user.primary_focused_journey.clear_first_camp_reveal!
    user
  end

  def bootstrap_plan(user)
    user.strategy_goals.for_kind("plan").not_holding.first
  end

  def win_first_bootstrap_battle!(user, camp)
    battle = camp.children.for_kind("day").first
    Strategy::CascadeToDaily.call(user: user, life_area: camp.life_area)
    todo = user.daily_todos.find_by!(strategy_goal_id: battle.id, scheduled_on: Date.current)
    post complete_daily_todo_path(todo)
    follow_redirect!
    battle.reload
    assert battle.completed?
  end

  # Mirrors arrange_camps_controller.js buildGroups (257–303) after dragging camp 3 into step 1 with camp 2.
  def build_groups_cross_step_payload(finished_camp:, active_camp_a:, active_camp_b:)
    {
      "0" => { camp_ids: [ finished_camp.id ] },
      "1" => { camp_ids: [ active_camp_b.id, active_camp_a.id ] }
    }
  end

  test "cross-step drag payload saves after bootstrap with won battle and completed first camp" do
    user = finish_onboarding!(email: "cross-step@example.com", camps: %w[Camp\ one Camp\ two Camp\ three])
    journey = user.primary_focused_journey
    plan = bootstrap_plan(user)
    camps = plan.children.for_kind("project").not_holding.order(:position).to_a
    camp1, camp2, camp3 = camps

    Strategy::HoldingProject.ensure!(user: user, journey: journey)
    win_first_bootstrap_battle!(user, camp1)
    camp1.complete!
    Strategy::SyncCompletion.call(project: camp1)

    patch life_journey_camp_arrangement_path(journey),
          params: {
            plan_id: plan.id,
            groups: build_groups_cross_step_payload(
              finished_camp: camp1,
              active_camp_a: camp2,
              active_camp_b: camp3
            )
          },
          as: :turbo_stream

    assert_response :success
    assert_equal 0, camp1.reload.stage
    assert_equal 1, camp3.reload.stage
    assert_equal 1, camp2.reload.stage
    assert_equal [ 0, 1, 2 ], [ camp1, camp3, camp2 ].map(&:position)
  end

  test "same-step reorder payload saves for bootstrap camps" do
    user = finish_onboarding!(email: "same-step@example.com", camps: %w[First Second])
    journey = user.primary_focused_journey
    plan = bootstrap_plan(user)
    camp1, camp2 = plan.children.for_kind("project").not_holding.order(:position).to_a

    Strategy::HoldingProject.ensure!(user: user, journey: journey)

    # buildGroups after dragging camp 2 into step 1 list (both on stage 0).
    patch life_journey_camp_arrangement_path(journey),
          params: {
            plan_id: plan.id,
            groups: { "0" => { camp_ids: [ camp2.id, camp1.id ] } }
          },
          as: :turbo_stream

    assert_response :success
    assert_equal 0, camp2.reload.stage
    assert_equal 0, camp1.reload.stage
    assert_equal 0, camp2.position
    assert_equal 1, camp1.position
  end

  test "completed camp stays first in group when reordering active camps" do
    user = finish_onboarding!(email: "finished-first@example.com", camps: %w[Done Next Last])
    journey = user.primary_focused_journey
    plan = bootstrap_plan(user)
    camp1, camp2, camp3 = plan.children.for_kind("project").not_holding.order(:position).to_a

    camp1.complete!
    Strategy::SyncCompletion.call(project: camp1)

    patch life_journey_camp_arrangement_path(journey),
          params: {
            plan_id: plan.id,
            groups: {
              "0" => { camp_ids: [ camp1.id ] },
              "1" => { camp_ids: [ camp3.id, camp2.id ] }
            }
          },
          as: :turbo_stream

    assert_response :success
    assert camp1.reload.completed?
    assert_equal 0, camp1.stage
    assert_equal 1, camp3.stage
    assert_equal 1, camp2.stage
    assert_equal [ 0, 1, 2 ], [ camp1, camp3, camp2 ].map(&:position)
  end

  test "missing camp in payload returns unprocessable entity" do
    user = finish_onboarding!(email: "missing-camp@example.com", camps: %w[One Two Three])
    journey = user.primary_focused_journey
    plan = bootstrap_plan(user)
    camp1, camp2, _camp3 = plan.children.for_kind("project").not_holding.order(:position).to_a

    patch life_journey_camp_arrangement_path(journey),
          params: {
            plan_id: plan.id,
            groups: { "0" => { camp_ids: [ camp2.id, camp1.id ] } }
          },
          as: :turbo_stream

    assert_response :unprocessable_entity
  end

  test "duplicate camp ids in payload returns camp_mismatch" do
    user = finish_onboarding!(email: "dup-payload@example.com", camps: %w[One Two])
    journey = user.primary_focused_journey
    plan = bootstrap_plan(user)
    camp1, camp2 = plan.children.for_kind("project").not_holding.order(:position).to_a
    camp1.complete!

    # Stale arrange DOM: finished list still has camp1 and active step still lists camp1 once.
    patch life_journey_camp_arrangement_path(journey),
          params: {
            plan_id: plan.id,
            groups: { "0" => { camp_ids: [ camp1.id, camp2.id, camp1.id ] } }
          },
          as: :turbo_stream

    assert_response :unprocessable_entity
    assert_equal 0, camp2.reload.position
  end

  test "open refreshes arrange overlay with all plan camps" do
    user = finish_onboarding!(email: "open-refresh@example.com", camps: %w[Alpha Beta])
    journey = user.primary_focused_journey
    plan = bootstrap_plan(user)
    camp1, _camp2 = plan.children.for_kind("project").not_holding.order(:position).to_a

    user.strategy_goals.create!(
      life_area: journey.life_area,
      life_journey: journey,
      parent: plan,
      horizon: "project",
      title: "Gamma",
      position: 2,
      stage: 2
    )

    post open_life_journey_camp_arrangement_path(journey),
         params: { plan_id: plan.id },
         as: :turbo_stream

    assert_response :success
    assert_match("trail-arrange-camps", response.body)
    assert_match(/data-camp-id="#{camp1.id}"/, response.body)
    assert_match(/Gamma/, response.body)
  end
end
