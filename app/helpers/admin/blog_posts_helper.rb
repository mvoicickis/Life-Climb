# frozen_string_literal: true

module Admin
  module BlogPostsHelper
    def admin_blog_post_card_date(post)
      if post.status == "published" && post.published_at.present?
        l(post.published_at.to_date, format: :long)
      else
        l(post.updated_at.to_date, format: :long)
      end
    end

    def admin_blog_save_status_copy(post)
      if post.status == "published"
        t("admin.blog_posts.save_status_published")
      else
        t("admin.blog_posts.save_status_draft")
      end
    end

    def admin_blog_writer_snapshot(post)
      {
        title: display_writer_title(post),
        body: post.body.to_plain_text.to_s,
        excerpt: post.excerpt.to_s,
        updated_at: post.persisted? ? post.updated_at.to_i : 0
      }.to_json
    end

    def display_writer_title(post)
      return "" if post.untitled_draft_title?

      post.title.to_s
    end
  end
end
