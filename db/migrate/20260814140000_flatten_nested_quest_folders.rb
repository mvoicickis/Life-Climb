# frozen_string_literal: true

class FlattenNestedQuestFolders < ActiveRecord::Migration[8.0]
  def up
    say_with_time "Flatten nested quest folders onto path-level projects" do
      Strategy::FlattenNestedFolders.call
    end
  end

  def down
    # Irreversible: folder rows, titles, and folder-level completion stamps
    # cannot be reconstructed after days merge onto the path camp.
  end
end
