# frozen_string_literal: true

class CreateDevBoardItems < ActiveRecord::Migration[8.0]
  def change
    create_table :dev_board_items do |t|
      t.string :title, null: false
      t.text :description
      t.string :kind, null: false, default: "bug"
      t.string :priority, null: false, default: "important"
      t.string :status, null: false, default: "todo"
      t.references :owner, null: false, foreign_key: { to_table: :users }
      t.references :reported_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.string :reporter_note
      t.datetime :done_at

      t.timestamps
    end

    add_index :dev_board_items, %i[status priority]
  end
end
