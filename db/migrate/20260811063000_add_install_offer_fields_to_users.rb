# frozen_string_literal: true

class AddInstallOfferFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :install_offer_dismissed_at, :datetime
    add_column :users, :install_offer_dismiss_count, :integer, null: false, default: 0
    add_column :users, :install_offer_installed_at, :datetime
  end
end
