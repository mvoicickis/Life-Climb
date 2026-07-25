class AddPlanningVersionAndV2LifeAreas < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :planning_version, :integer, null: false, default: 1

    change_column_null :life_areas, :dream_id, true
    add_column :life_areas, :selected_at, :datetime

    # v2 selected areas have no dream; uniqueness is per user+key for those rows.
    add_index :life_areas, [ :user_id, :key ],
              unique: true,
              where: "dream_id IS NULL",
              name: "index_life_areas_v2_on_user_id_and_key"
  end
end
