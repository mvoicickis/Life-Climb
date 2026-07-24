class AddTotalPointsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :total_points, :integer, default: 0, null: false
  end
end
