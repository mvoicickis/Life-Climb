# frozen_string_literal: true

require "test_helper"

class StrategyClimbPathNodesHelperTest < ActionView::TestCase
  include StrategyHelper

  Node = Strategy::Trail::Node

  test "returns empty for blank trail" do
    assert_empty strategy_climb_path_nodes(nil)
  end

  test "returns every node including locked ones beyond the old three-camp cap" do
    nodes = [
      Node.new(id: 1, title: "A", state: :done, pct: 100, position: 0, record: nil, y: 80),
      Node.new(id: 2, title: "B", state: :done, pct: 100, position: 1, record: nil, y: 70),
      Node.new(id: 3, title: "C", state: :current, pct: 40, position: 2, record: nil, y: 50),
      Node.new(id: 4, title: "D", state: :locked, pct: 0, position: 3, record: nil, y: 40),
      Node.new(id: 5, title: "E", state: :locked, pct: 0, position: 4, record: nil, y: 30),
      Node.new(id: 6, title: "F", state: :locked, pct: 0, position: 5, record: nil, y: 20),
      Node.new(id: 7, title: "G", state: :locked, pct: 0, position: 6, record: nil, y: 10),
      Node.new(id: 8, title: "H", state: :locked, pct: 0, position: 7, record: nil, y: 5)
    ]
    trail = Strategy::Trail::Result.new(nodes: nodes, visible_nodes: [], current_node: nodes[2])

    path = strategy_climb_path_nodes(trail)
    assert_equal 8, path.size
    assert_equal [ 1, 2, 3, 4, 5, 6, 7, 8 ], path.map(&:id)
  end

  test "when all done returns every done node" do
    nodes = [
      Node.new(id: 1, title: "A", state: :done, pct: 100, position: 0, record: nil, y: 80),
      Node.new(id: 2, title: "B", state: :done, pct: 100, position: 1, record: nil, y: 60)
    ]
    trail = Strategy::Trail::Result.new(nodes: nodes, visible_nodes: nodes, current_node: nodes.last)

    path = strategy_climb_path_nodes(trail)
    assert_equal %i[done done], path.map(&:state)
  end

  test "quantified meta has a ratio; battle counts never do" do
    user = users(:one)
    Onboarding::Run.call(
      user: user, area_key: "career", title: "Ship",
      ideal_scene: "Live", current_reality: "Building", next_win: "Launch",
      today_mission: "Write tests", closer_percent: 20, route_mission: true
    )
    journey = user.reload.primary_focused_journey
    area = journey.life_area
    goal = user.strategy_goals.for_kind("goal").roots.first
    plan = goal.children.create!(
      user: user, life_area: area, life_journey: journey,
      horizon: "plan", title: "Main", position: 0
    )
    quant = plan.children.create!(
      user: user, life_area: area, life_journey: journey,
      horizon: "project", title: "Save", position: 0,
      target_amount: 600, unit: "€", current_amount: 340
    )
    battles = plan.children.create!(
      user: user, life_area: area, life_journey: journey,
      horizon: "project", title: "Hunt", position: 1
    )
    2.times do |i|
      day = battles.children.create!(
        user: user, life_area: area, life_journey: journey,
        horizon: "day", title: "Day #{i}", scheduled_on: Date.current, position: i
      )
      day.update_columns(completed_at: Time.current) if i.zero?
    end

    quant_meta = strategy_project_card_meta(quant)
    assert_match(/340 \/ 600/, quant_meta[:label])
    assert_in_delta 340.0 / 600.0, quant_meta[:ratio], 0.001

    battle_meta = strategy_project_card_meta(battles)
    assert_equal I18n.t("strategy.rpg.project_battles_won", count: 1), battle_meta[:label]
    assert_nil battle_meta[:ratio]
  end
end
