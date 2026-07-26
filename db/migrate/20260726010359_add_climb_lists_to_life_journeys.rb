# frozen_string_literal: true

class AddClimbListsToLifeJourneys < ActiveRecord::Migration[8.1]
  def change
    add_column :life_journeys, :approaches, :json, null: false, default: []
    add_column :life_journeys, :programs, :json, null: false, default: []
    add_column :life_journeys, :milestones, :json, null: false, default: []
  end
end
