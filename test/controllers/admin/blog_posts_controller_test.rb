# frozen_string_literal: true

require "test_helper"

module Admin
  class BlogPostsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @admin = users(:admin)
      @user = users(:one)
    end

    def assert_script_load_order!
      body = response.body
      importmap_at = body.index('type="importmap"')
      admin_blog_at = body.index('import "admin_blog"')

      assert importmap_at, "expected importmap script"
      assert admin_blog_at, "expected admin_blog module import"
      assert_operator importmap_at, :<, admin_blog_at
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

    test "admin new opens the writer without creating a post" do
      sign_in_as @admin

      assert_no_difference -> { BlogPost.count } do
        get new_admin_blog_post_path
      end

      assert_response :success
      assert_select "#blog_post_editor"
      assert_no_match(/lp-blog-writer__status-ok/, response.body)
      assert_select "button", text: I18n.t("admin.blog_posts.save_draft")
      assert_select "button", text: I18n.t("admin.blog_posts.publish")
    end

    test "first autosave with body only and blank title creates untitled draft" do
      sign_in_as @admin

      assert_difference -> { BlogPost.count }, 1 do
        post admin_blog_posts_path, params: {
          autosave: "1",
          blog_post: { title: "", body: "Mountain story text only." }
        }, headers: { Accept: "text/vnd.turbo-stream.html" }
      end

      assert_response :success
      created = BlogPost.order(:id).last
      assert_equal BlogPost::UNTITLED_TITLE, created.title
      assert created.auto_draft_slug?
      assert_includes created.body.to_plain_text, "Mountain story text only."
    end

    test "publish with blank title keeps draft and shows error" do
      sign_in_as @admin
      post_record = BlogPost.create!(
        title: BlogPost::UNTITLED_TITLE,
        slug: "draft-testslug1",
        status: "draft"
      )
      post_record.body = "Body without a real title."
      post_record.save!

      patch publish_admin_blog_post_path(post_record)

      assert_response :unprocessable_entity
      assert_match I18n.t("admin.blog_posts.publish_title_required"), response.body
      assert_equal "draft", post_record.reload.status
    end

    test "duplicate blank title drafts get unique slugs" do
      sign_in_as @admin

      2.times do |index|
        post admin_blog_posts_path, params: {
          autosave: "1",
          blog_post: { title: "", body: "Story #{index}." }
        }, headers: { Accept: "text/vnd.turbo-stream.html" }

        assert_response :success
      end

      slugs = BlogPost.order(:id).last(2).map(&:slug)
      assert_equal 2, slugs.uniq.length
      assert slugs.all? { |slug| slug.match?(/\Adraft-[a-z0-9]+\z/) }
    end

    test "first autosave on new post creates the record" do
      sign_in_as @admin
      get new_admin_blog_post_path

      assert_difference -> { BlogPost.count }, 1 do
        post admin_blog_posts_path, params: {
          autosave: "1",
          slug_auto: "1",
          blog_post: { title: "My first story" }
        }, headers: { Accept: "text/vnd.turbo-stream.html" }
      end

      assert_response :success
      created = BlogPost.order(:id).last
      assert_equal "My first story", created.title
      assert_match(/lp-blog-writer__status-ok/, response.body)
    end

    test "failed autosave shows not saved message" do
      sign_in_as @admin
      BlogPost.create!(title: "Taken", slug: "taken-slug", status: "draft")
      post_record = BlogPost.create!(title: "Other", slug: "other-slug", status: "draft")

      patch admin_blog_post_path(post_record), params: {
        autosave: "1",
        blog_post: { slug: "taken-slug" }
      }, headers: { Accept: "text/vnd.turbo-stream.html" }

      assert_response :unprocessable_entity
      assert_match I18n.t("admin.blog_posts.not_saved_tap"), response.body
      assert_no_match(/lp-blog-writer__status-ok/, response.body)
    end

    test "autosave syncs slug field from server when slug is auto" do
      sign_in_as @admin
      post_record = BlogPost.create!(title: "Hello World", slug: "hello-world", status: "draft")

      patch admin_blog_post_path(post_record), params: {
        autosave: "1",
        slug_auto: "1",
        blog_post: { title: "You'll Climb", slug: "youll-climb" }
      }, headers: { Accept: "text/vnd.turbo-stream.html" }

      assert_response :success
      post_record.reload
      assert_equal "youll-climb", post_record.slug
      assert_match(/value="youll-climb"/, response.body)
    end

    test "autosave never publishes" do
      sign_in_as @admin
      post_record = BlogPost.create!(title: "Autosave me", status: "draft")

      patch admin_blog_post_path(post_record), params: {
        autosave: "1",
        blog_post: {
          title: "Still a draft",
          body: "Updated body copy."
        }
      }, headers: { Accept: "text/vnd.turbo-stream.html" }

      assert_response :success
      post_record.reload
      assert_equal "draft", post_record.status
      assert_nil post_record.published_at
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

    test "blog list loads writer assets for turbo visits" do
      sign_in_as @admin
      get admin_blog_posts_path

      assert_response :success
      assert_select "link[rel=stylesheet][href*='actiontext']"
      assert_match(/admin_blog/, response.body)
      assert_script_load_order!
    end

    test "edit writer shows title textarea and visible google check" do
      sign_in_as @admin
      post_record = BlogPost.create!(title: "Writer layout test", status: "draft")

      get edit_admin_blog_post_path(post_record)

      assert_response :success
      assert_select "link[rel=stylesheet][href*='actiontext']"
      assert_match(/admin_blog/, response.body)
      assert_script_load_order!
      assert_select "textarea.lp-blog-writer__title[name=?]", "blog_post[title]"
      assert_select "#blog_google_preview"
      assert_select "#blog_seo_checklist"
      assert_select "details.lp-blog-writer__seo-panel", count: 0
      assert_select "details.lp-blog-writer__seo-edit summary", text: I18n.t("admin.blog_posts.edit_google_text")
      assert_select "[data-blog-writer-target=?]", "previewTitle", text: "Writer layout test"
      assert_select "button", text: I18n.t("admin.blog_posts.save_draft")
      assert_select "button", text: I18n.t("admin.blog_posts.publish")
    end

    test "page title does not double escape apostrophes" do
      sign_in_as @admin
      post_record = BlogPost.create!(title: "You'll climb", status: "draft")

      get edit_admin_blog_post_path(post_record)

      assert_response :success
      assert_match %r{<title>You(?:'|&#39;)ll climb · Admin · Life Climb</title>}, response.body
      assert_no_match %r{&amp;#39;}, response.body
    end

    test "admin can preview a draft with noindex banner" do
      sign_in_as @admin
      post_record = BlogPost.create!(title: "Draft preview test", status: "draft")
      post_record.body = "Preview body text."
      post_record.save!

      get preview_admin_blog_post_path(post_record)

      assert_response :success
      assert_match I18n.t("blog.draft_preview_banner"), response.body
      assert_match(/Preview body text/, response.body)
      assert_match %r{<meta name="robots" content="noindex, nofollow">}, response.body
    end

    test "non admin cannot preview a post" do
      sign_in_as @user
      post_record = BlogPost.create!(title: "Secret draft", status: "draft")

      get preview_admin_blog_post_path(post_record)

      assert_redirected_to dashboard_path
    end

    test "guest cannot preview a post" do
      post_record = BlogPost.create!(title: "Secret draft", status: "draft")

      get preview_admin_blog_post_path(post_record)

      assert_redirected_to new_session_path
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
