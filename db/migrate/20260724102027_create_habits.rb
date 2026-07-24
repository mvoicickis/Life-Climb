class CreateHabits < ActiveRecord::Migration[8.1]
  def change
    create_table :habits do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.integer :points, null: false, default: 5
      t.string :frequency, null: false, default: "daily"
      t.boolean :active, null: false, default: true

      t.timestamps
    end
  end
end
