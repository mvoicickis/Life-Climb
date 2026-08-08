# frozen_string_literal: true

require "test_helper"

# Verifies the migration backfill SQL shape: a Project that only had habit_id
# would become a join row so "Improve Income" style data is not orphaned.
class HabitProjectLinksBackfillTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @area = life_areas(:one_self)
    @habit = habits(:one)
    @goal = @user.strategy_goals.create!(life_area: @area, horizon: "goal", title: "Season", position: 0)
    @plan = @user.strategy_goals.create!(
      life_area: @area, parent: @goal, horizon: "plan", title: "Path", position: 0
    )
    @project = @user.strategy_goals.create!(
      life_area: @area, parent: @plan, horizon: "project", title: "Improve Income", position: 0
    )
  end

  test "backfill sql copies legacy habit_id onto habit_project_links" do
    conn = ActiveRecord::Base.connection
    unless StrategyGoal.column_names.include?("habit_id")
      conn.add_column :strategy_goals, :habit_id, :integer
      StrategyGoal.reset_column_information
    end

    HabitProjectLink.where(strategy_goal_id: @project.id).delete_all
    conn.execute("UPDATE strategy_goals SET habit_id = #{@habit.id} WHERE id = #{@project.id}")

    conn.execute(<<~SQL.squish)
      INSERT INTO habit_project_links (habit_id, strategy_goal_id, created_at, updated_at)
      SELECT habit_id, id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM strategy_goals
      WHERE habit_id IS NOT NULL
        AND NOT EXISTS (
          SELECT 1 FROM habit_project_links
          WHERE habit_project_links.strategy_goal_id = strategy_goals.id
            AND habit_project_links.habit_id = strategy_goals.habit_id
        )
    SQL

    link = HabitProjectLink.find_by!(habit_id: @habit.id, strategy_goal_id: @project.id)
    assert_equal "Improve Income", link.strategy_goal.title
    assert_includes @habit.reload.improvement_projects, @project

    conn.remove_column :strategy_goals, :habit_id
    StrategyGoal.reset_column_information
  end
end
