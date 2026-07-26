class AddAlignmentFieldsToLifeJourneys < ActiveRecord::Migration[8.1]
  def change
    add_column :life_journeys, :purpose, :text
    add_column :life_journeys, :policy, :text
    add_column :life_journeys, :approach, :text
    add_column :life_journeys, :program, :text
    add_column :life_journeys, :finished_result, :text
  end
end
