# frozen_string_literal: true

class AddMountainTrailTourAckToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :mountain_trail_tour_ack, :integer, null: false, default: 0
  end
end
