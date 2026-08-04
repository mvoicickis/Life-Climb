# frozen_string_literal: true

class AddLifeJourneyToHabits < ActiveRecord::Migration[8.0]
  def change
    add_reference :habits, :life_journey, null: true, foreign_key: true
  end
end
