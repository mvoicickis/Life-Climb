# frozen_string_literal: true

require "test_helper"

class Strategy::FlattenNestedFoldersTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @area = life_areas(:one_self)
    @goal = @user.strategy_goals.create!(life_area: @area, horizon: "goal", title: "Season", position: 0)
    @plan = @user.strategy_goals.create!(
      life_area: @area, parent: @goal, horizon: "plan", title: "Path", position: 0
    )
  end

  test "moves open and completed days up, copies colors, deletes folders, keeps tasks and quantity logs" do
    agree = create_path_camp!("Agree camp", position: 0, target_amount: 100, unit: "pages")
    conflict = create_path_camp!("Conflict camp", position: 1)

    teal_folder = nest_folder!(agree, "Teal folder", position: 0, color_key: "teal")
    also_teal = nest_folder!(agree, "Also teal", position: 1, color_key: "teal")
    coral_folder = nest_folder!(conflict, "Coral folder", position: 0, color_key: "coral")
    purple_folder = nest_folder!(conflict, "Purple folder", position: 1, color_key: "purple")

    agree_open = nest_day!(teal_folder, "Agree open", position: 0)
    agree_done = nest_day!(teal_folder, "Agree done", position: 1)
    agree_done.update_columns(completed_at: Time.current)
    agree_second = nest_day!(also_teal, "Agree second", position: 0)

    conflict_open = nest_day!(coral_folder, "Conflict open", position: 0)
    conflict_done = nest_day!(purple_folder, "Conflict done", position: 1)
    conflict_done.update_columns(completed_at: Time.current)

    task = agree_open.practice_tasks.create!(user: @user, title: "Do a lesson", position: 0)
    log = @user.strategy_quantity_logs.create!(
      strategy_goal: agree,
      source_day: agree_open,
      amount: 12,
      unit: "pages",
      logged_on: Date.current
    )
    points_before = @user.total_points

    Strategy::FlattenNestedFolders.call

    assert_not StrategyGoal.exists?(teal_folder.id)
    assert_not StrategyGoal.exists?(also_teal.id)
    assert_not StrategyGoal.exists?(coral_folder.id)
    assert_not StrategyGoal.exists?(purple_folder.id)

    assert_equal agree.id, agree_open.reload.parent_id
    assert_equal agree.id, agree_done.reload.parent_id
    assert_equal agree.id, agree_second.reload.parent_id
    assert_equal conflict.id, conflict_open.reload.parent_id
    assert_equal conflict.id, conflict_done.reload.parent_id

    assert agree_done.completed?
    assert conflict_done.completed?
    assert_nil agree_open.completed_at
    assert_nil conflict_open.completed_at

    agree_days = agree.reload.children.where(horizon: "day").order(:position, :id)
    assert_equal [ agree_open.id, agree_done.id, agree_second.id ], agree_days.map(&:id)
    assert_equal [ 0, 1, 2 ], agree_days.map(&:position)

    conflict_days = conflict.reload.children.where(horizon: "day").order(:position, :id)
    assert_equal [ conflict_open.id, conflict_done.id ], conflict_days.map(&:id)
    assert_equal [ 0, 1 ], conflict_days.map(&:position)

    assert_equal "teal", agree_open.reload.color_key
    assert_equal "teal", agree_done.reload.color_key
    assert_equal "teal", agree_second.reload.color_key
    assert_equal "teal", agree.reload.color_key

    assert_equal "coral", conflict_open.reload.color_key
    assert_equal "purple", conflict_done.reload.color_key
    assert_nil conflict.reload.color_key

    assert PracticeTask.exists?(task.id)
    assert_equal agree_open.id, task.reload.strategy_goal_id
    assert StrategyQuantityLog.exists?(log.id)
    assert_equal agree.id, log.reload.strategy_goal_id
    assert_equal agree_open.id, log.source_day_id
    assert_equal points_before, @user.reload.total_points
  end

  test "flattens a two-deep branch and keeps existing path-level days first" do
    camp = create_path_camp!("Deep camp", position: 0)
    already = nest_day!(camp, "Already on camp", position: 3)
    mid = nest_folder!(camp, "Mid", position: 0)
    leaf = nest_folder!(mid, "Leaf", position: 0)
    deep_day = nest_day!(leaf, "Deep day", position: 0)

    Strategy::FlattenNestedFolders.call

    assert_not StrategyGoal.exists?(mid.id)
    assert_not StrategyGoal.exists?(leaf.id)
    days = camp.reload.children.where(horizon: "day").order(:position, :id)
    assert_equal [ already.id, deep_day.id ], days.map(&:id)
    assert_equal [ 0, 1 ], days.map(&:position)
    assert_equal camp.id, already.reload.parent_id
    assert_equal camp.id, deep_day.reload.parent_id
  end

  private

  def create_path_camp!(title, position:, target_amount: nil, unit: nil)
    @user.strategy_goals.create!(
      life_area: @area, parent: @plan, horizon: "project", title: title,
      position: position, target_amount: target_amount, unit: unit
    )
  end

  def nest_folder!(parent, title, position:, color_key: nil)
    folder = StrategyGoal.new(
      user: @user, life_area: @area, parent: parent, horizon: "project",
      title: title, position: position, color_key: color_key
    )
    folder.save!(validate: false)
    folder
  end

  def nest_day!(parent, title, position:)
    day = StrategyGoal.new(
      user: @user, life_area: @area, parent: parent, horizon: "day",
      title: title, scheduled_on: Date.current, position: position
    )
    day.save!(validate: false)
    day
  end
end
