class CreateLifeAreas < ActiveRecord::Migration[8.1]
  def change
    create_table :life_areas do |t|
      t.references :user, null: false, foreign_key: true
      t.references :dream, null: false, foreign_key: true
      t.string :key, null: false
      t.integer :number, null: false
      t.text :ambition
      t.json :meta, null: false, default: {}
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :life_areas, [:dream_id, :key], unique: true
    add_index :life_areas, [:user_id, :number]

    add_reference :goals, :life_area, foreign_key: true, null: true
  end
end
