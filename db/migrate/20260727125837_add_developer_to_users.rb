# frozen_string_literal: true

class AddDeveloperToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :developer, :boolean, default: false, null: false
  end
end
