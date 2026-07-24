class AddTrackingFieldsToHabits < ActiveRecord::Migration[8.1]
  def change
    add_column :habits, :unit, :string, null: false, default: "times"
    add_column :habits, :show_on_home, :boolean, null: false, default: true
  end
end
