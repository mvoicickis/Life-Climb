# frozen_string_literal: true

class AddQuantityCheckinToHabits < ActiveRecord::Migration[8.0]
  def up
    add_column :habits, :quantity_checkin, :boolean, null: false, default: false

    # Preserve today's heuristic so existing behavior stays stable.
    execute <<~SQL.squish
      UPDATE habits
      SET quantity_checkin = CASE
        WHEN stat_type = 'standard' THEN TRUE
        WHEN goal IS NOT NULL THEN TRUE
        WHEN lower(unit) != 'times' THEN TRUE
        ELSE FALSE
      END
    SQL

    # Known false negative: countable "times" habits named like Push-Ups.
    execute <<~SQL.squish
      UPDATE habits
      SET quantity_checkin = TRUE
      WHERE quantity_checkin = FALSE
        AND lower(name) LIKE '%push%up%'
    SQL

    # Evidence of quantity use — binary habits log via completions, not daily_logs.
    execute <<~SQL.squish
      UPDATE habits
      SET quantity_checkin = TRUE
      WHERE quantity_checkin = FALSE
        AND id IN (SELECT DISTINCT habit_id FROM daily_logs WHERE habit_id IS NOT NULL)
    SQL
  end

  def down
    remove_column :habits, :quantity_checkin
  end
end
