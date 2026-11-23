# frozen_string_literal: true

class CreateBetaTesters < ActiveRecord::Migration[8.1]
  def change
    create_table :beta_testers do |t|
      t.string :email, null: false
      t.datetime :added_at, null: false
      t.references :user, null: true, foreign_key: true, index: true

      t.timestamps
    end

    add_index :beta_testers, :email, unique: true
  end
end
