# frozen_string_literal: true

class AddAspectKeyToMissions < ActiveRecord::Migration[8.1]
  def change
    add_column :missions, :aspect_key, :string
  end
end
