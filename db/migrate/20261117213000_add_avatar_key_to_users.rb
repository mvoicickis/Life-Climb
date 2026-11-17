# frozen_string_literal: true

class AddAvatarKeyToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :avatar_key, :string
  end
end
