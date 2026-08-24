# frozen_string_literal: true

class AddQuantityKindToStrategyGoals < ActiveRecord::Migration[8.0]
  def change
    add_column :strategy_goals, :quantity_kind, :string, null: false, default: "none"
    add_column :strategy_goals, :range_min, :decimal, precision: 12, scale: 2
    add_column :strategy_goals, :range_max, :decimal, precision: 12, scale: 2

    reversible do |dir|
      dir.up do
        execute <<~SQL.squish
          UPDATE strategy_goals
          SET quantity_kind = 'up'
          WHERE target_amount IS NOT NULL AND target_amount > 0
        SQL
      end
    end
  end
end
