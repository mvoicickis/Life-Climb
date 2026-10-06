# frozen_string_literal: true

require "test_helper"

class TodayEmptyBattleCtaTest < ActiveSupport::TestCase
  include ClimbTestHelper
  test "no journey points at start climb" do
    cta = Today::EmptyBattleCta.for(journey: nil, handoff: nil)

    assert_equal I18n.t("dash.battlefield.empty_cta.start_climb"), cta[:label]
    assert_includes cta[:href], "/life_journeys/new"
  end

  test "maps handoff steps to pill copy and hrefs" do
    user = users(:one)
    journey = seed_climb!(user, today_mission: "Unused")
    project_id = 42
    plan_id = 7

    lock = Today::EmptyBattleCta.for(journey:, handoff: { step: :lock_goal })
    assert_equal I18n.t("dash.battlefield.empty_cta.set_goal"), lock[:label]
    assert_includes lock[:href], journey.id.to_s

    handoff_label = "Add a plan under “Ship LifePoints”"
    plan = Today::EmptyBattleCta.for(journey:, handoff: { step: :add_plan, plan_id:, label: handoff_label })
    assert_equal handoff_label, plan[:label]
    assert_includes plan[:href], "/life_journeys/#{journey.id}"
    refute_includes plan[:href], "notebook=1"

    camp = Today::EmptyBattleCta.for(journey:, handoff: { step: :add_project, plan_id: })
    assert_equal I18n.t("dash.battlefield.empty_cta.add_next_camp"), camp[:label]
    assert_includes camp[:href], "open_plant=1"

    battle = Today::EmptyBattleCta.for(journey:, handoff: { step: :add_battle, project_id: })
    assert_equal I18n.t("dash.battlefield.empty_cta.add_todays_battle"), battle[:label]
    assert_includes battle[:href], "open_camp=#{project_id}"
    assert_includes battle[:href], "open_composer=1"

    open = Today::EmptyBattleCta.for(journey:, handoff: { step: :open_strategy, project_id: })
    assert_equal battle[:label], open[:label]
    assert_includes open[:href], "open_camp=#{project_id}"
    assert_includes open[:href], "open_composer=1"

    resolved = Today::EmptyBattleCta.for(
      journey:,
      handoff: { step: :open_strategy, project_id: nil }
    )
    assert_includes resolved[:href], "open_camp=#{Strategy::PathProject.resolve(user:, journey:).id}"

    summit = Today::EmptyBattleCta.for(
      journey:,
      handoff: { step: :summit_next_goal, label: "Choose your next goal", href: "/summit_next_goal" }
    )
    assert_equal "Choose your next goal", summit[:label]
    assert_equal "/summit_next_goal", summit[:href]
  end
end
