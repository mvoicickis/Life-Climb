# frozen_string_literal: true

class AddQuickAddAmountToHabits < ActiveRecord::Migration[8.0]
  def change
    add_column :habits, :quick_add_amount, :integer
  end
end
