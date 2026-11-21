# frozen_string_literal: true

class AddLastFinaleOnToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :last_finale_on, :date
  end
end
