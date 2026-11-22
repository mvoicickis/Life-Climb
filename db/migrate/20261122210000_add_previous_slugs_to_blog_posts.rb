# frozen_string_literal: true

class AddPreviousSlugsToBlogPosts < ActiveRecord::Migration[8.1]
  def change
    add_column :blog_posts, :previous_slugs, :json, null: false, default: []
  end
end
