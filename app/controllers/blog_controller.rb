# frozen_string_literal: true

class BlogController < ApplicationController
  allow_unauthenticated_access
  skip_onboarding_check
  layout "blog"

  def index
    @blog_posts = BlogPost.published
  end

  def show
    slug = params[:slug].to_s
    @blog_post = BlogPost.find_published_by_current_slug(slug)

    if @blog_post.nil?
      legacy = BlogPost.find_published_by_legacy_slug(slug)
      if legacy
        redirect_to blog_post_path(legacy.slug), status: :moved_permanently
        return
      end

      raise ActiveRecord::RecordNotFound
    end

    @related_posts = BlogPost.related_for(@blog_post)
  end
end
