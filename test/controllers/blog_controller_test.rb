# frozen_string_literal: true

require "test_helper"

class BlogControllerTest < ActionDispatch::IntegrationTest
  setup do
    @published = BlogPost.create!(
      title: "Published climb tips",
      slug: "published-climb-tips",
      status: "published",
      published_at: 2.days.ago,
      seo_title: "Climb tips SEO",
      meta_description: "How to win one battle a day."
    )
    @published.body = "One " * 250
    @published.save!

    @draft = BlogPost.create!(
      title: "Still drafting",
      slug: "still-drafting",
      status: "draft"
    )
  end

  test "blog index is public and lists published posts only" do
    get blog_path

    assert_response :success
    assert_includes response.body, @published.title
    assert_not_includes response.body, @draft.title
    assert_match(/#{Regexp.escape(I18n.t("blog.min_read", count: @published.reading_minutes))}/, response.body)
  end

  test "draft slug returns not found" do
    get blog_post_path(@draft.slug)

    assert_response :not_found
  end

  test "scheduled post returns not found before published_at" do
    travel_to Time.zone.parse("2026-11-22 12:00:00") do
      scheduled = BlogPost.create!(
        title: "Scheduled climb",
        slug: "scheduled-climb",
        status: "published",
        published_at: 1.day.from_now
      )

      get blog_post_path(scheduled.slug)

      assert_response :not_found
    end
  end

  test "old slug redirects to current published post" do
    BlogPost.create!(
      title: "Renamed climb tips",
      slug: "renamed-climb-tips",
      status: "published",
      published_at: 2.days.ago,
      previous_slugs: [ "legacy-climb-tips" ]
    )

    get blog_post_path("legacy-climb-tips")

    assert_redirected_to blog_post_path("renamed-climb-tips")
    assert_response :moved_permanently
  end

  test "published post body images include width and height" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("fake-image"),
      filename: "inline.png",
      content_type: "image/png"
    )
    blob.update!(metadata: blob.metadata.merge("width" => 640, "height" => 480))

    post = BlogPost.create!(
      title: "Post with image",
      slug: "post-with-image",
      status: "published",
      published_at: 1.day.ago
    )
    post.body = ActionText::Attachment.from_attachable(blob).to_html
    post.save!

    get blog_post_path(post.slug)

    assert_response :success
    assert_match(/width="640"/, response.body)
    assert_match(/height="480"/, response.body)
  end

  test "published post renders meta og and json-ld" do
    get blog_post_path(@published.slug)

    assert_response :success
    assert_match(/<title>Climb tips SEO<\/title>/, response.body)
    assert_match(/name="description" content="How to win one battle a day\."/, response.body)
    assert_match(/property="og:title" content="Climb tips SEO"/, response.body)
    assert_match(/property="og:description" content="How to win one battle a day\."/, response.body)
    assert_match(/property="og:type" content="article"/, response.body)
    assert_match(/application\/ld\+json/, response.body)
    assert_match(/"@type":"BlogPosting"/, response.body)
    assert_match(/"headline":"Published climb tips"/, response.body)
    assert_match(%r{rel="canonical" href="https://lifeclimb\.app/blog/published-climb-tips"}, response.body)
  end

  test "sitemap includes blog and published posts only" do
    get "/sitemap.xml"

    assert_response :success
    assert_match %r{<loc>https://lifeclimb\.app/blog</loc>}, response.body
    assert_match %r{<loc>https://lifeclimb\.app/blog/published-climb-tips</loc>}, response.body
    assert_no_match %r{still-drafting}, response.body
  end
end
