# frozen_string_literal: true

require "test_helper"

class StrategyClimbPathNodesHelperTest < ActionView::TestCase
  include StrategyHelper

  Node = Strategy::Trail::Node

  test "returns empty for blank trail" do
    assert_empty strategy_climb_path_nodes(nil)
  end

  test "includes all done and current plus capped locked ahead" do
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
    assert_equal 6, path.size
    assert_equal %i[done done current locked locked locked], path.map(&:state)
    assert_equal [ 1, 2, 3, 4, 5, 6 ], path.map(&:id)
    refute_includes path.map(&:id), 7
    refute_includes path.map(&:id), 8
  end

  test "respects custom locked_ahead" do
    nodes = [
      Node.new(id: 1, title: "Now", state: :current, pct: 10, position: 0, record: nil, y: 50),
      Node.new(id: 2, title: "L1", state: :locked, pct: 0, position: 1, record: nil, y: 40),
      Node.new(id: 3, title: "L2", state: :locked, pct: 0, position: 2, record: nil, y: 30),
      Node.new(id: 4, title: "L3", state: :locked, pct: 0, position: 3, record: nil, y: 20)
    ]
    trail = Strategy::Trail::Result.new(nodes: nodes, visible_nodes: [], current_node: nodes[0])

    path = strategy_climb_path_nodes(trail, locked_ahead: 1)
    assert_equal 2, path.size
    assert_equal [ 1, 2 ], path.map(&:id)
  end

  test "when all done returns only done nodes" do
    nodes = [
      Node.new(id: 1, title: "A", state: :done, pct: 100, position: 0, record: nil, y: 80),
      Node.new(id: 2, title: "B", state: :done, pct: 100, position: 1, record: nil, y: 60)
    ]
    trail = Strategy::Trail::Result.new(nodes: nodes, visible_nodes: nodes, current_node: nodes.last)

    path = strategy_climb_path_nodes(trail)
    assert_equal %i[done done], path.map(&:state)
  end

  test "fewer locked than cap returns all locked" do
    nodes = [
      Node.new(id: 1, title: "Now", state: :current, pct: 10, position: 0, record: nil, y: 50),
      Node.new(id: 2, title: "L1", state: :locked, pct: 0, position: 1, record: nil, y: 40)
    ]
    trail = Strategy::Trail::Result.new(nodes: nodes, visible_nodes: nodes, current_node: nodes[0])

    path = strategy_climb_path_nodes(trail)
    assert_equal 2, path.size
    assert_equal [ 1, 2 ], path.map(&:id)
  end
end
