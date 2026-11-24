# frozen_string_literal: true

module Admin
  class BlogPostsController < BaseController
    before_action :set_blog_post, only: %i[ edit update destroy publish unpublish remove_cover preview ]

    def index
      @blog_posts = BlogPost.order(created_at: :desc)
    end

    def new
      @blog_post = BlogPost.new(author_name: default_author_name, status: "draft")
      render :edit
    end

    def create
      autosaving = params[:autosave].to_s == "1"
      publishing = params[:publish].to_s == "1"
      @blog_post = BlogPost.new(blog_post_params)
      @blog_post.author_name = default_author_name if @blog_post.author_name.blank?
      @blog_post.sync_slug_from_title = params[:slug_auto].to_s == "1"
      @replace_editor = true

      if @blog_post.save
        return complete_publish(publishing, autosaving) if publishing

        respond_to do |format|
          format.turbo_stream { render :autosave, status: :ok }
          format.html { redirect_to edit_admin_blog_post_path(@blog_post), notice: t("admin.blog_posts.updated") }
        end
      else
        @replace_editor = false
        respond_to do |format|
          format.turbo_stream { render :autosave_error, status: :unprocessable_entity }
          format.html { render :edit, status: :unprocessable_entity }
        end
      end
    end

    def edit
    end

    def preview
      @draft_preview = !@blog_post.published?
      @related_posts = @blog_post.published? ? BlogPost.related_for(@blog_post) : []
      response.headers["X-Robots-Tag"] = "noindex, nofollow"

      render :preview, layout: "blog"
    end

    def update
      autosaving = params[:autosave].to_s == "1"
      publishing = params[:publish].to_s == "1"
      @blog_post.assign_attributes(blog_post_params)
      @blog_post.sync_slug_from_title = params[:slug_auto].to_s == "1"
      @replace_editor = false

      if @blog_post.save
        return complete_publish(publishing, autosaving) if publishing

        respond_to do |format|
          format.turbo_stream do
            autosaving ? render(:autosave, status: :ok) : head(:ok)
          end
          format.html do
            redirect_to edit_admin_blog_post_path(@blog_post), notice: t("admin.blog_posts.updated")
          end
        end
      else
        respond_to do |format|
          format.turbo_stream { render :autosave_error, status: :unprocessable_entity }
          format.html { render :edit, status: :unprocessable_entity }
        end
      end
    end

    def destroy
      @blog_post.destroy!
      redirect_to admin_blog_posts_path, notice: t("admin.blog_posts.deleted")
    end

    def publish
      if @blog_post.publish_now!
        redirect_to edit_admin_blog_post_path(@blog_post), notice: t("admin.blog_posts.published")
      else
        @publish_error = true
        render :edit, status: :unprocessable_entity
      end
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

    def complete_publish(_publishing, autosaving)
      if @blog_post.publish_now!
        redirect_to edit_admin_blog_post_path(@blog_post), notice: t("admin.blog_posts.published")
        return
      end

      @publish_error = true
      @replace_editor = action_name == "create" && @blog_post.persisted?
      respond_to do |format|
        format.turbo_stream { render :publish_error, status: :unprocessable_entity }
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end
end