class AddEffortTierToStrategyGoals < ActiveRecord::Migration[8.1]
  def change
    add_column :strategy_goals, :effort_tier, :string
  end
end
