# frozen_string_literal: true

class AddSeenAtToHighFives < ActiveRecord::Migration[8.0]
  def change
    add_column :high_fives, :seen_at, :datetime
  end
end
