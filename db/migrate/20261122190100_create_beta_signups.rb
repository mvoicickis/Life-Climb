# frozen_string_literal: true

class CreateBetaSignups < ActiveRecord::Migration[8.1]
  def change
    create_table :beta_signups do |t|
      t.string :email, null: false
      t.string :source_path
      t.string :device
      t.string :user_agent

      t.timestamps
    end

    add_index :beta_signups, :email, unique: true
  end
end
