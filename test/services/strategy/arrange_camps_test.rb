# frozen_string_literal: true

require "test_helper"

class StrategyArrangeCampsTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    allow_extra_climbs!(@user)
    @area = @user.life_areas.first || @user.life_areas.create!(key: "career", number: 9)
    @goal = @user.strategy_goals.create!(life_area: @area, horizon: "goal", title: "Goal", position: 0)
    @plan = @user.strategy_goals.create!(
      life_area: @area, parent: @goal, horizon: "plan", title: "Plan", position: 0
    )
    @a = @user.strategy_goals.create!(
      life_area: @area, parent: @plan, horizon: "project", title: "A", position: 0, stage: 0
    )
    @b = @user.strategy_goals.create!(
      life_area: @area, parent: @plan, horizon: "project", title: "B", position: 1, stage: 1
    )
    @c = @user.strategy_goals.create!(
      life_area: @area, parent: @plan, horizon: "project", title: "C", position: 2, stage: 2
    )
  end

  test "assigns contiguous stage and global position from groups" do
    Strategy::ArrangeCamps.call(
      user: @user,
      plan: @plan,
      groups: [ { camp_ids: [ @c.id, @a.id ] }, { camp_ids: [ @b.id ] } ]
    )

    assert_equal [ 0, 1, 2 ], [ @c, @a, @b ].map { |camp| camp.reload.position }
    assert_equal [ 0, 0, 1 ], [ @c, @a, @b ].map(&:stage)
  end

  test "two camps on same stage share stage index with ordered positions" do
    @b.update_columns(stage: 0, position: 1)

    Strategy::ArrangeCamps.call(
      user: @user,
      plan: @plan,
      groups: [ { camp_ids: [ @a.id, @b.id ] }, { camp_ids: [ @c.id ] } ]
    )

    assert_equal 0, @a.reload.stage
    assert_equal 0, @b.reload.stage
    assert_equal 1, @c.reload.stage
    assert_equal [ 0, 1, 2 ], [ @a, @b, @c ].map(&:position)
  end

  test "completed camp stage updates when layout renumbers" do
    @a.complete!
    @a.update_columns(stage: 0, position: 0)
    @b.update_columns(stage: 1, position: 1)
    @c.update_columns(stage: 2, position: 2)

    Strategy::ArrangeCamps.call(
      user: @user,
      plan: @plan,
      groups: [ { camp_ids: [ @b.id ] }, { camp_ids: [ @a.id, @c.id ] } ]
    )

    assert_equal 0, @b.reload.stage
    assert_equal 1, @a.reload.stage
    assert_equal 1, @c.reload.stage
    assert @a.completed?
  end

  test "rejects camp id mismatch" do
    assert_raises(Strategy::ArrangeCamps::Invalid) do
      Strategy::ArrangeCamps.call(
        user: @user,
        plan: @plan,
        groups: [ { camp_ids: [ @a.id, @b.id ] } ]
      )
    end
  end

  test "rejects unauthorized user" do
    other = users(:two)
    assert_raises(Strategy::ArrangeCamps::Invalid) do
      Strategy::ArrangeCamps.call(user: other, plan: @plan, groups: [ { camp_ids: [ @a.id, @b.id, @c.id ] } ])
    end
  end
end
