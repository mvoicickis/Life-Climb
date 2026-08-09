# frozen_string_literal: true

class AddCommitmentToLifeJourneys < ActiveRecord::Migration[8.0]
  def change
    change_table :life_journeys, bulk: true do |t|
      t.string :commitment_name, null: false, default: "Easy"
      t.integer :commitment_habit_count, null: false, default: 1
      t.integer :commitment_battle_count, null: false, default: 1
      t.string :commitment_key, null: false, default: "easy"
      t.integer :commitment_met_streak_days, null: false, default: 0
      t.date :commitment_met_on
      t.date :commitment_level_up_declined_on
    end
  end
end
