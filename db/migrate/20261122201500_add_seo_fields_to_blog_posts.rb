# frozen_string_literal: true

class AddSeoFieldsToBlogPosts < ActiveRecord::Migration[8.1]
  def change
    add_column :blog_posts, :seo_title, :string
    add_column :blog_posts, :meta_description, :string
    add_column :blog_posts, :focus_phrase, :string
  end
end
