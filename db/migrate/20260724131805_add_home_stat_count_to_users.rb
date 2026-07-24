class AddHomeStatCountToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :home_stat_count, :integer, null: false, default: 6
  end
end
