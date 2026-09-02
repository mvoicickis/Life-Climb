# frozen_string_literal: true

class AddPushOfferFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :push_offer_dismiss_count, :integer, null: false, default: 0
    add_column :users, :push_offer_dismissed_at, :datetime
    add_column :users, :push_offer_permission_denied_at, :datetime
  end
end
