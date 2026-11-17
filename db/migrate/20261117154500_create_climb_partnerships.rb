# frozen_string_literal: true

class CreateClimbPartnerships < ActiveRecord::Migration[8.1]
  def change
    create_table :climb_partnerships do |t|
      t.references :inviter, null: false, foreign_key: { to_table: :users }
      t.references :invitee, null: true, foreign_key: { to_table: :users }
      t.string :token, null: false
      t.string :status, null: false, default: "pending"
      t.datetime :accepted_at
      t.datetime :ended_at

      t.timestamps
    end

    add_index :climb_partnerships, :token, unique: true
  end
end
