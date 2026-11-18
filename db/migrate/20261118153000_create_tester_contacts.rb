# frozen_string_literal: true

class CreateTesterContacts < ActiveRecord::Migration[8.1]
  def change
    create_table :tester_contacts do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :channel
      t.string :details
      t.date :last_contacted_on
      t.string :note
      t.references :updated_by, null: true, foreign_key: { to_table: :users }

      t.timestamps
    end
  end
end
