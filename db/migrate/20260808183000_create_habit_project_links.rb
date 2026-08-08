# frozen_string_literal: true

class CreateHabitProjectLinks < ActiveRecord::Migration[8.0]
  def up
    create_table :habit_project_links do |t|
      t.references :habit, null: false, foreign_key: true
      t.references :strategy_goal, null: false, foreign_key: true
      t.timestamps
    end
    add_index :habit_project_links, [ :habit_id, :strategy_goal_id ],
              unique: true,
              name: "index_habit_project_links_on_habit_and_project"

    say_with_time "backfill habit_project_links from strategy_goals.habit_id" do
      execute <<~SQL.squish
        INSERT INTO habit_project_links (habit_id, strategy_goal_id, created_at, updated_at)
        SELECT habit_id, id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
        FROM strategy_goals
        WHERE habit_id IS NOT NULL
      SQL
    end

    remove_reference :strategy_goals, :habit, foreign_key: true
  end

  def down
    add_reference :strategy_goals, :habit, null: true, foreign_key: true

    execute <<~SQL.squish
      UPDATE strategy_goals
      SET habit_id = (
        SELECT habit_project_links.habit_id
        FROM habit_project_links
        WHERE habit_project_links.strategy_goal_id = strategy_goals.id
        ORDER BY habit_project_links.id ASC
        LIMIT 1
      )
      WHERE EXISTS (
        SELECT 1 FROM habit_project_links
        WHERE habit_project_links.strategy_goal_id = strategy_goals.id
      )
    SQL

    drop_table :habit_project_links
  end
end
