# frozen_string_literal: true

require "test_helper"

module Admin
  class BlogPostsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @admin = users(:admin)
      @user = users(:one)
    end

    test "non admin cannot open blog posts" do
      sign_in_as @user
      get admin_blog_posts_path

      assert_redirected_to dashboard_path
      follow_redirect!
      assert_match(/Access denied/i, flash[:alert].to_s + response.body)
    end

    test "guest is sent to sign in" do
      get admin_blog_posts_path
      assert_redirected_to new_session_path
    end

    test "admin can create a draft post" do
      sign_in_as @admin

      assert_difference -> { BlogPost.count }, 1 do
        post admin_blog_posts_path, params: {
          blog_post: {
            title: "Why one battle a day",
            author_name: "Karen",
            body: "Small steps add up."
          }
        }
      end

      post = BlogPost.order(:id).last
      assert_equal "draft", post.status
      assert_equal "why-one-battle-a-day", post.slug
      assert_redirected_to edit_admin_blog_post_path(post)
    end

    test "publish sets published_at on first publish" do
      travel_to Time.zone.parse("2026-11-22 10:00:00") do
        sign_in_as @admin
        post_record = BlogPost.create!(title: "Ready to ship")

        patch publish_admin_blog_post_path(post_record)

        assert_redirected_to edit_admin_blog_post_path(post_record)
        post_record.reload
        assert_equal "published", post_record.status
        assert_equal Time.zone.parse("2026-11-22 10:00:00"), post_record.published_at
      end
    end

    test "admin can update a post" do
      sign_in_as @admin
      post_record = BlogPost.create!(title: "Old title", slug: "old-title")

      patch admin_blog_post_path(post_record), params: {
        blog_post: {
          title: "New title",
          slug: "new-title",
          author_name: "Karen",
          excerpt: "A short teaser."
        }
      }

      assert_redirected_to edit_admin_blog_post_path(post_record)
      post_record.reload
      assert_equal "New title", post_record.title
      assert_equal "new-title", post_record.slug
      assert_equal "A short teaser.", post_record.excerpt
    end

    test "admin can destroy a post" do
      sign_in_as @admin
      post_record = BlogPost.create!(title: "Gone soon")

      assert_difference -> { BlogPost.count }, -1 do
        delete admin_blog_post_path(post_record)
      end

      assert_redirected_to admin_blog_posts_path
      assert_nil BlogPost.find_by(id: post_record.id)
    end
  end
end