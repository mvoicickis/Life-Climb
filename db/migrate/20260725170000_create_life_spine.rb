class CreateLifeSpine < ActiveRecord::Migration[8.1]
  def change
    create_table :dreams do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    create_table :goals do |t|
      t.references :user, null: false, foreign_key: true
      t.references :dream, null: false, foreign_key: true
      t.string :title, null: false
      t.string :status, null: false, default: "active"
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    create_table :steps do |t|
      t.references :user, null: false, foreign_key: true
      t.references :goal, null: false, foreign_key: true
      t.string :title, null: false
      t.string :status, null: false, default: "pending"
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    create_table :buildings do |t|
      t.references :user, null: false, foreign_key: true
      t.references :step, null: false, foreign_key: true
      t.string :title, null: false
      t.text :summary
      t.string :status, null: false, default: "active"
      t.datetime :shipped_at
      t.timestamps
    end

    create_table :today_actions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :building, null: false, foreign_key: true
      t.string :title, null: false
      t.date :scheduled_on, null: false
      t.datetime :completed_at
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    create_table :finished_products do |t|
      t.references :user, null: false, foreign_key: true
      t.references :building, foreign_key: true
      t.references :goal, foreign_key: true
      t.string :title, null: false
      t.text :value_summary
      t.date :shipped_on, null: false
      t.timestamps
    end

    create_table :life_point_ledgers do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :amount, null: false
      t.string :reason, null: false
      t.string :source_type
      t.integer :source_id
      t.timestamps
    end

    add_index :today_actions, [ :building_id, :scheduled_on ]
    add_index :today_actions, [ :user_id, :scheduled_on ]
    add_index :life_point_ledgers, [ :source_type, :source_id ]
    add_index :buildings, [ :user_id, :status ]
    add_index :goals, [ :user_id, :position ]
    add_index :steps, [ :goal_id, :position ]

    add_reference :users, :focus_building, foreign_key: { to_table: :buildings }, null: true
    add_column :users, :onboarding_completed_at, :datetime
  end
end
