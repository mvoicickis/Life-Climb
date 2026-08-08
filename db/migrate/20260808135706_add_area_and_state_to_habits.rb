# frozen_string_literal: true

class AddAreaAndStateToHabits < ActiveRecord::Migration[8.0]
  def change
    add_reference :habits, :area, null: true, foreign_key: true
    add_column :habits, :state, :string
    add_column :habits, :state_label_good, :string
    add_column :habits, :state_label_attention, :string
  end
end
