# frozen_string_literal: true

class AddSetupFlagsToLifeJourneys < ActiveRecord::Migration[8.1]
  def change
    add_column :life_journeys, :setup_flags, :json, null: false, default: {}
  end
end
