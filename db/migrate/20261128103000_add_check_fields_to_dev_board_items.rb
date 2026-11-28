# frozen_string_literal: true

class AddCheckFieldsToDevBoardItems < ActiveRecord::Migration[8.0]
  def change
    add_column :dev_board_items, :check_note, :string
    add_reference :dev_board_items, :work_owner, foreign_key: { to_table: :users }
  end
end