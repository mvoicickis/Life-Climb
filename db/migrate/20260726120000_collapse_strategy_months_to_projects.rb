# frozen_string_literal: true

class CollapseStrategyMonthsToProjects < ActiveRecord::Migration[8.0]
  def up
    say_with_time "Collapse strategy month/week nodes into projects" do
      Strategy::CollapseMonths.call
    end
  end

  def down
    # Irreversible data migration.
  end
end
