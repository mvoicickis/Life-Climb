# frozen_string_literal: true

class AddAppOpenMarkersToUsers < ActiveRecord::Migration[8.1]
  def change
    change_table :users, bulk: true do |t|
      t.date :last_opened_on
      t.datetime :next_app_open_at
    end
  end
end
