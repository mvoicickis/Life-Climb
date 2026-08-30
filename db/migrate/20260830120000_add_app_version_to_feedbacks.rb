# frozen_string_literal: true

class AddAppVersionToFeedbacks < ActiveRecord::Migration[8.1]
  def change
    add_column :feedbacks, :app_version, :string
  end
end
