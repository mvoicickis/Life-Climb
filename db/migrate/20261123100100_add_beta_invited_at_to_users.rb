# frozen_string_literal: true

class AddBetaInvitedAtToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :beta_invited_at, :datetime
    add_index :users, :beta_invited_at
  end
end
