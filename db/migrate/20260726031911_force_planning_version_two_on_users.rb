# frozen_string_literal: true

class ForcePlanningVersionTwoOnUsers < ActiveRecord::Migration[8.0]
  def up
    change_column_default :users, :planning_version, from: 1, to: 2
    # Legacy tree Home (planning_version 1) is retired — everyone uses one-mountain v2.
    execute "UPDATE users SET planning_version = 2 WHERE planning_version IS NULL OR planning_version < 2"
  end

  def down
    change_column_default :users, :planning_version, from: 2, to: 1
  end
end
