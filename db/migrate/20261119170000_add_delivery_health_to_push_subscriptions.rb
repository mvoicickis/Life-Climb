# frozen_string_literal: true

class AddDeliveryHealthToPushSubscriptions < ActiveRecord::Migration[8.0]
  def change
    add_column :push_subscriptions, :last_success_at, :datetime
    add_column :push_subscriptions, :last_error_at, :datetime
    add_column :push_subscriptions, :last_error, :string
  end
end
