class CreateCompletions < ActiveRecord::Migration[8.1]
  def change
    create_table :completions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :habit, null: false, foreign_key: true
      t.date :completed_on, null: false
      t.integer :points_awarded, null: false

      t.timestamps
    end

    add_index :completions, [ :habit_id, :completed_on ], unique: true
  end
end
