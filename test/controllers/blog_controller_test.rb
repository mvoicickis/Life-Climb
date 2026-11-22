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
