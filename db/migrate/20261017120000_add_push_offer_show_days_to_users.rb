# frozen_string_literal: true

class AddPushOfferShowDaysToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :push_offer_show_days, :integer, null: false, default: 0
  end
end
