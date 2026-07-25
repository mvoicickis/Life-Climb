# frozen_string_literal: true

class AddNextWinToLifeJourneys < ActiveRecord::Migration[8.1]
  def change
    add_column :life_journeys, :next_win, :text
  end
end
