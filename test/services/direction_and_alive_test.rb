require "test_helper"

class AliveLevelTest < ActiveSupport::TestCase
  test "picks titles from points" do
    assert_equal "spark", AliveLevel.new(0).key
    assert_equal "glow", AliveLevel.new(50).key
    assert_equal "force", AliveLevel.new(1000).key
  end

  test "next level hint shows remaining points" do
    level = AliveLevel.new(10)
    assert_match(/50/, level.next_level_hint)
  end
end

class DirectionSignalTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @building = buildings(:one)
    @area = life_areas(:one_community)
  end

  test "getting started when actions exist but none done" do
    actions = @building.today_actions.for_day(Date.current)
    actions.update_all(completed_at: nil)
    signal = DirectionSignal.new(user: @user, building: @building, actions: actions.reload, life_area: @area)
    assert_equal "getting_started", signal.status
  end

  test "on track when an action is done" do
    actions = @building.today_actions.for_day(Date.current).to_a
    actions.first.update!(completed_at: Time.current)
    signal = DirectionSignal.new(user: @user, building: @building, actions: actions, life_area: @area)
    assert_equal "on_track", signal.status
  end

  test "gap hint when ideal and present differ" do
    signal = DirectionSignal.new(user: @user, building: @building, actions: [], life_area: @area)
    assert_match(/gap|Ideal|Present/i, signal.gap_hint.to_s)
  end
end
