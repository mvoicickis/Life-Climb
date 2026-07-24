class CreateDailyLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :daily_logs do |t|
      t.references :habit, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.date :logged_on, null: false
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.decimal :goal, precision: 12, scale: 2

      t.timestamps
    end

    add_index :daily_logs, [ :habit_id, :logged_on ], unique: true
  end
end
