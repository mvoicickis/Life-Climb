# frozen_string_literal: true

class DevBoardIdeasColumn < ActiveRecord::Migration[8.0]
  def up
    execute <<-SQL.squish
      UPDATE dev_board_items SET status = 'idea' WHERE status = 'later'
    SQL
    change_column_default :dev_board_items, :status, from: "todo", to: "idea"
  end

  def down
    change_column_default :dev_board_items, :status, from: "idea", to: "todo"
    execute <<-SQL.squish
      UPDATE dev_board_items SET status = 'later' WHERE status = 'idea'
    SQL
  end
end