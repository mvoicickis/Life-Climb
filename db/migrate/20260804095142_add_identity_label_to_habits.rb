# frozen_string_literal: true

class AddIdentityLabelToHabits < ActiveRecord::Migration[8.0]
  def change
    add_column :habits, :identity_label, :string
  end
end
