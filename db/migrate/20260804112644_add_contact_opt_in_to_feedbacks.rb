# frozen_string_literal: true

class AddContactOptInToFeedbacks < ActiveRecord::Migration[8.0]
  def change
    add_column :feedbacks, :ok_to_contact, :boolean, null: false, default: false
    add_column :feedbacks, :contact_info, :string
  end
end
