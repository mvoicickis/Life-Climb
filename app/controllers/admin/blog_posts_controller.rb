# frozen_string_literal: true

module Admin
  class BlogPostsController < BaseController
    before_action :set_blog_post, only: %i[ edit update destroy publish unpublish ]

    def index
      @blog_posts = BlogPost.order(created_at: :desc)
    end

    def new
      @blog_post = BlogPost.new(author_name: default_author_name, status: "draft")
    end

    def create
      @blog_post = BlogPost.new(blog_post_params)
      if @blog_post.save
        redirect_to edit_admin_blog_post_path(@blog_post), notice: t("admin.blog_posts.created")
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @blog_post.update(blog_post_params)
        redirect_to edit_admin_blog_post_path(@blog_post), notice: t("admin.blog_posts.updated")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @blog_post.destroy!
      redirect_to admin_blog_posts_path, notice: t("admin.blog_posts.deleted")
    end

    def publish
      attrs = { status: "published" }
      attrs[:published_at] = Time.current if @blog_post.published_at.blank?
      @blog_post.update!(attrs)
      redirect_to edit_admin_blog_post_path(@blog_post), notice: t("admin.blog_posts.published")
    end

    def unpublish
      @blog_post.update!(status: "draft")
      redirect_to edit_admin_blog_post_path(@blog_post), notice: t("admin.blog_posts.unpublished")
    end

    private

    def set_blog_post
      @blog_post = BlogPost.find(params[:id])
    end

    def blog_post_params
      params.require(:blog_post).permit(:title, :slug, :excerpt, :author_name, :cover_photo, :body)
    end

    def default_author_name
      t("admin.blog_posts.default_author")
    end
  end
end
