# frozen_string_literal: true

module Admin
  class BlogPostsController < BaseController
    before_action :set_blog_post, only: %i[ edit update destroy publish unpublish remove_cover ]

    def index
      @blog_posts = BlogPost.order(created_at: :desc)
    end

    def new
      @blog_post = BlogPost.create!(
        title: t("admin.blog_posts.untitled"),
        author_name: default_author_name,
        status: "draft"
      )
      redirect_to edit_admin_blog_post_path(@blog_post)
    end

    def edit
    end

    def update
      autosaving = params[:autosave].to_s == "1"
      @blog_post.assign_attributes(blog_post_params)

      if @blog_post.save
        respond_to do |format|
          format.turbo_stream do
            autosaving ? render(:autosave) : head(:ok)
          end
          format.html do
            redirect_to edit_admin_blog_post_path(@blog_post), notice: t("admin.blog_posts.updated")
          end
        end
      else
        respond_to do |format|
          format.turbo_stream { head :unprocessable_entity }
          format.html { render :edit, status: :unprocessable_entity }
        end
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

    def remove_cover
      @blog_post.cover_photo.purge
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to edit_admin_blog_post_path(@blog_post) }
      end
    end

    private

    def set_blog_post
      @blog_post = BlogPost.find(params[:id])
    end

    def blog_post_params
      params.require(:blog_post).permit(
        :title,
        :slug,
        :excerpt,
        :author_name,
        :cover_photo,
        :body,
        :seo_title,
        :meta_description,
        :focus_phrase
      )
    end

    def default_author_name
      t("admin.blog_posts.default_author")
    end
  end
end
