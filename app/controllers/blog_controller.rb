# frozen_string_literal: true

class BlogController < ApplicationController
  allow_unauthenticated_access
  skip_onboarding_check
  layout "blog"

  def index
    @blog_posts = BlogPost.published
  end

  def show
    @blog_post = BlogPost.published.find_by!(slug: params[:slug])
    @related_posts = BlogPost.related_for(@blog_post)
  end
end
