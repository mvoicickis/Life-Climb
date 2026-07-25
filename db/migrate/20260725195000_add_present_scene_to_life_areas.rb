class AddPresentSceneToLifeAreas < ActiveRecord::Migration[8.1]
  def change
    add_column :life_areas, :present_scene, :text
    add_column :life_areas, :closer_score, :integer, null: false, default: 1
  end
end
