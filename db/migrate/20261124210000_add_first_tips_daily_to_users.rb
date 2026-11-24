# frozen_string_literal: true

class AddFirstTipsDailyToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :first_tips_daily, :json, null: false, default: {}
  end
end