# frozen_string_literal: true

class AddStageToStrategyGoals < ActiveRecord::Migration[8.1]
  class << self
    private

    def backfill_stages!
      StrategyGoal.where(horizon: "plan").find_each do |plan|
        StrategyGoal
          .where(parent_id: plan.id, horizon: "project", holding: false)
          .order(:position, :id)
          .each_with_index do |camp, idx|
            camp.update_columns(stage: idx, updated_at: Time.current)
          end
      end
    end
  end

  def change
    add_column :strategy_goals, :stage, :integer, null: false, default: 0
    add_index :strategy_goals, [ :parent_id, :stage, :position ],
              name: "index_strategy_goals_on_parent_id_stage_and_position"

    reversible do |dir|
      dir.up { self.class.send(:backfill_stages!) }
    end
  end
end
