class AddPositionToHabits < ActiveRecord::Migration[8.1]
  def change
    add_column :habits, :position, :integer, null: false, default: 0
    add_index :habits, [ :user_id, :position ]
  end
end
