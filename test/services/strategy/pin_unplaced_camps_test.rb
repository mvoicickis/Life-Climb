# frozen_string_literal: true

require "test_helper"

class Strategy::PinUnplacedCampsTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @area = life_areas(:one_self)
    allow_extra_climbs!(@user)
    @goal = @user.strategy_goals.create!(
      life_area: @area, horizon: "goal", title: "Pin summit", position: 0
    )
    @plan = @user.strategy_goals.create!(
      life_area: @area, parent: @goal, horizon: "plan", title: "Pin path", position: 0
    )
  end

  test "writes auto slots only for camps missing coords" do
    placed = @user.strategy_goals.create!(
      life_area: @area, parent: @plan, horizon: "project", title: "Planted",
      position: 0, trail_x: 0.4, trail_y: 0.7
    )
    unplaced = @user.strategy_goals.create!(
      life_area: @area, parent: @plan, horizon: "project", title: "Loose",
      position: 1
    )

    Strategy::PinUnplacedCamps.call(projects: [ placed, unplaced ])

    placed.reload
    unplaced.reload
    assert_in_delta 0.4, placed.trail_x, 0.0001
    assert_in_delta 0.7, placed.trail_y, 0.0001
    expected = MountainTrailHelper::AutoSlot.call(index: 1, total: 2, sparse: true)
    assert_in_delta expected[:trail_x], unplaced.trail_x, 0.0001
    assert_in_delta expected[:trail_y], unplaced.trail_y, 0.0001
  end

  test "second call is a no-op once camps are pinned" do
    camp = @user.strategy_goals.create!(
      life_area: @area, parent: @plan, horizon: "project", title: "Once",
      position: 0
    )
    Strategy::PinUnplacedCamps.call(projects: [ camp ])
    first_x = camp.reload.trail_x
    first_y = camp.trail_y
    first_updated = camp.updated_at

    travel 2.seconds do
      Strategy::PinUnplacedCamps.call(projects: [ camp ])
    end

    camp.reload
    assert_in_delta first_x, camp.trail_x, 0.0001
    assert_in_delta first_y, camp.trail_y, 0.0001
    assert_equal first_updated.to_i, camp.updated_at.to_i
  end
end
