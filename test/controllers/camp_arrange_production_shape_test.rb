# frozen_string_literal: true

require "test_helper"

class CampArrangeProductionShapeTest < ActionDispatch::IntegrationTest
  # Render production duplicate: camp 1101 in stage-0 group and again alone in group 1.
  PRODUCTION_DUPLICATE_GROUPS = {
    "0" => { camp_ids: [ 1101, 1220, 1103, 1151 ] },
    "1" => { camp_ids: [ 1101 ] },
    "2" => { camp_ids: [ 1098, 1149 ] },
    "3" => { camp_ids: [ 1131, 1099 ] },
    "4" => { camp_ids: [ 1100 ] }
  }.freeze

  def finish_onboarding_many_camps!(email:)
    titles = %w[C1101 C1220 C1103 C1151 C1098 C1149 C1131 C1099 C1100]
    post registration_url, params: {
      user: {
        name: "Alex",
        email_address: email,
        password: "password12345",
        password_confirmation: "password12345"
      }
    }
    follow_redirect!
    patch v2_onboarding_url(step: "goal"), params: { onboarding: { goal: "Big climb" } }
    patch v2_onboarding_url(step: "camps"), params: { onboarding: { camp_titles: titles.first(3) } }
    follow_redirect!
    user = User.find_by!(email_address: email)
    user.primary_focused_journey.clear_first_camp_reveal!
    plan = user.strategy_goals.for_kind("plan").not_holding.first
    journey = user.primary_focused_journey
    area = journey.life_area
    titles.drop(3).each_with_index do |title, index|
      user.strategy_goals.create!(
        life_area: area,
        life_journey: journey,
        parent: plan,
        horizon: "project",
        title: title,
        position: index + 3,
        stage: index + 3,
        stage_explicit: true
      )
    end
    user
  end

  def map_production_ids_to_plan(plan)
    by_title = plan.children.for_kind("project").not_holding.index_by(&:title)
    {
      1101 => by_title["C1101"],
      1220 => by_title["C1220"],
      1103 => by_title["C1103"],
      1151 => by_title["C1151"],
      1098 => by_title["C1098"],
      1149 => by_title["C1149"],
      1131 => by_title["C1131"],
      1099 => by_title["C1099"],
      1100 => by_title["C1100"]
    }
  end

  def remap_groups(template, id_map)
    template.transform_keys(&:to_s).transform_values do |entry|
      { camp_ids: entry[:camp_ids].map { |legacy_id| id_map.fetch(legacy_id).id } }
    end
  end

  test "production duplicate payload returns duplicate_camp_id" do
    user = finish_onboarding_many_camps!(email: "prod-dup@example.com")
    journey = user.primary_focused_journey
    plan = user.strategy_goals.for_kind("plan").not_holding.first
    id_map = map_production_ids_to_plan(plan)
    camp1101 = id_map.fetch(1101)
    camp1101.complete!

    duplicate = remap_groups(PRODUCTION_DUPLICATE_GROUPS, id_map)

    patch life_journey_camp_arrangement_path(journey),
          params: { plan_id: plan.id, groups: duplicate },
          as: :turbo_stream

    assert_response :unprocessable_entity
  end

  test "deduped production shape saves when completed camp only in finished bucket" do
    user = finish_onboarding_many_camps!(email: "prod-fix@example.com")
    journey = user.primary_focused_journey
    plan = user.strategy_goals.for_kind("plan").not_holding.first
    id_map = map_production_ids_to_plan(plan)
    camp1101 = id_map.fetch(1101)
    camp1101.complete!

    # buildGroups after global dedupe: camp1101 only in stage-0 group (finished), not group 1.
    deduped = remap_groups(
      {
        "0" => { camp_ids: [ 1101, 1220, 1103, 1151 ] },
        "2" => { camp_ids: [ 1098, 1149 ] },
        "3" => { camp_ids: [ 1131, 1099 ] },
        "4" => { camp_ids: [ 1100 ] }
      },
      id_map
    )

    patch life_journey_camp_arrangement_path(journey),
          params: { plan_id: plan.id, groups: deduped },
          as: :turbo_stream

    assert_response :success
    assert camp1101.reload.completed?
    assert_equal 0, camp1101.stage
  end

  test "completed camp in active step and finished list shape rejects duplicate" do
    user = finish_onboarding_many_camps!(email: "stale-step@example.com")
    journey = user.primary_focused_journey
    plan = user.strategy_goals.for_kind("plan").not_holding.first
    camps = plan.children.for_kind("project").not_holding.order(:position).to_a
    finished = camps.first
    finished.complete!

    # Stale DOM: finished camp still listed in stage-1 active group and in stage-0 finished group.
    patch life_journey_camp_arrangement_path(journey),
          params: {
            plan_id: plan.id,
            groups: {
              "0" => { camp_ids: [ finished.id, camps[1].id ] },
              "1" => { camp_ids: [ finished.id, camps[2].id ] }
            }
          },
          as: :turbo_stream

    assert_response :unprocessable_entity
  end
end
