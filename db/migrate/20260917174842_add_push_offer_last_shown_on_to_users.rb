# frozen_string_literal: true

class AddPushOfferLastShownOnToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :push_offer_last_shown_on, :date
  end
end
