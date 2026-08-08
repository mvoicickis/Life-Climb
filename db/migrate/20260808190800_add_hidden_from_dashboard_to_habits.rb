# frozen_string_literal: true

class AddHiddenFromDashboardToHabits < ActiveRecord::Migration[8.0]
  def change
    add_column :habits, :hidden_from_dashboard, :boolean, null: false, default: false
  end
end
