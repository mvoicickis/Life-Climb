# frozen_string_literal: true

class ImproveFeedbacksForTesters < ActiveRecord::Migration[8.0]
  def change
    change_column_null :feedbacks, :user_id, true
    add_column :feedbacks, :page_context, :string
    add_column :feedbacks, :rating, :integer
    add_index :feedbacks, :page_context
  end
end
