class AddStatTypesToHabits < ActiveRecord::Migration[8.1]
  def change
    add_column :habits, :stat_type, :string, null: false, default: "growth"
    add_column :habits, :goal, :decimal, precision: 12, scale: 2
    add_column :habits, :min_value, :decimal, precision: 12, scale: 2
    add_column :habits, :max_value, :decimal, precision: 12, scale: 2
    add_column :habits, :goal_raise_declined_on, :date
  end
end
