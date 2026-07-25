class CreateLifeJourneysMissionsAndGapSnapshots < ActiveRecord::Migration[8.1]
  def change
    create_table :life_journeys do |t|
      t.references :user, null: false, foreign_key: true
      t.references :life_area, null: false, foreign_key: true
      t.string :title, null: false
      t.text :ideal_scene, null: false
      t.text :current_reality, null: false
      t.datetime :scenes_revised_at
      t.string :status, null: false, default: "active"
      t.integer :focus_position
      t.decimal :gap_percent, precision: 5, scale: 2, null: false, default: 70.0
      t.datetime :activated_at
      t.datetime :completed_at
      t.timestamps
    end

    add_index :life_journeys, [ :user_id, :focus_position ],
              unique: true,
              where: "focus_position IS NOT NULL",
              name: "index_life_journeys_on_user_focus_position"
    add_index :life_journeys, [ :user_id, :status ]
    add_index :life_journeys, [ :life_area_id, :status ]

    create_table :missions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :life_journey, null: false, foreign_key: true
      t.string :title, null: false
      t.date :scheduled_on, null: false
      t.integer :lp_reward, null: false, default: 50
      t.integer :gap_delta_basis_points, null: false, default: 80
      t.datetime :completed_at
      t.string :status, null: false, default: "pending"
      t.integer :position, null: false, default: 0
      t.string :source, null: false, default: "system"
      t.boolean :is_primary, null: false, default: false
      t.timestamps
    end

    add_index :missions, [ :user_id, :scheduled_on ]
    add_index :missions, [ :life_journey_id, :scheduled_on ]
    add_index :missions, [ :user_id, :life_journey_id, :scheduled_on, :is_primary ],
              unique: true,
              where: "is_primary = TRUE AND status != 'replaced'",
              name: "index_missions_one_primary_per_journey_day"

    create_table :gap_snapshots do |t|
      t.references :life_journey, null: false, foreign_key: true
      t.date :recorded_on, null: false
      t.decimal :gap_percent, precision: 5, scale: 2, null: false
      t.timestamps
    end

    add_index :gap_snapshots, [ :life_journey_id, :recorded_on ], unique: true
  end
end
