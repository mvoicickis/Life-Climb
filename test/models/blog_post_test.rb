# frozen_string_literal: true

require "test_helper"

class BlogPostTest < ActiveSupport::TestCase
  test "requires title" do
    post = BlogPost.new(title: "", slug: "hello")

    assert_not post.valid?
    assert_includes post.errors[:title], "can't be blank"
  end

  test "assigns slug from title when blank" do
    post = BlogPost.new(title: "Why One Battle a Day")

    assert post.valid?
    assert_equal "why-one-battle-a-day", post.slug
  end

  test "keeps an edited slug" do
    post = BlogPost.create!(title: "Camps Not Finish Lines", slug: "custom-camp-slug")
    post.update!(title: "A totally different title")

    assert_equal "custom-camp-slug", post.reload.slug
  end

  test "slug must be unique" do
    BlogPost.create!(title: "First", slug: "shared-slug")
    duplicate = BlogPost.new(title: "Second", slug: "shared-slug")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:slug], "has already been taken"
  end

  test "defaults to draft" do
    post = BlogPost.create!(title: "Draft by default")

    assert_equal "draft", post.status
  end

  test "related_for excludes current post" do
    first = BlogPost.create!(
      title: "First",
      slug: "related-first",
      status: "published",
      published_at: 2.days.ago
    )
    second = BlogPost.create!(
      title: "Second",
      slug: "related-second",
      status: "published",
      published_at: 1.day.ago
    )

    related = BlogPost.related_for(first)

    assert_equal [ second ], related.to_a
  end

  test "published scope is newest first and hides future or draft" do
    travel_to Time.zone.parse("2026-11-22 12:00:00") do
      old = BlogPost.create!(
        title: "Old published",
        status: "published",
        published_at: 2.days.ago
      )
      newest = BlogPost.create!(
        title: "Newest published",
        status: "published",
        published_at: 1.hour.ago
      )
      BlogPost.create!(
        title: "Draft",
        status: "draft",
        published_at: 1.hour.ago
      )
      BlogPost.create!(
        title: "Scheduled",
        status: "published",
        published_at: 1.hour.from_now
      )

      assert_equal [ newest, old ], BlogPost.published.to_a
    end
  end

  test "reading_minutes is at least one" do
    post = BlogPost.create!(title: "Short")

    assert_equal 1, post.reading_minutes
  end

  test "reading_minutes rounds up from word count" do
    post = BlogPost.create!(title: "Long read")
    post.body = ([ "word" ] * 250).join(" ")

    assert_equal 2, post.reading_minutes
  end

  test "seo_title defaults from title when blank" do
    post = BlogPost.create!(title: "A" * 80)

    assert_equal 60, post.seo_title.length
    assert_equal ("A" * 60), post.seo_title
  end

  test "excerpt defaults from body when blank" do
    words = ([ "climb" ] * 80).join(" ")
    post = BlogPost.create!(title: "Excerpt test", body: words)

    assert_operator post.excerpt.length, :<=, BlogPost::EXCERPT_LENGTH
    assert_includes post.excerpt, "climb"
  end

  test "meta description defaults from excerpt when blank" do
    post = BlogPost.create!(title: "Meta", body: "One line about the climb.")
    post.reload

    assert post.meta_description.present?
    assert_operator post.meta_description.length, :<=, BlogPost::META_DESCRIPTION_MAX
  end

  test "seo checklist reflects focus phrase and headings" do
    post = BlogPost.create!(title: "How to climb daily", focus_phrase: "climb")
    post.body = "<h2>Start</h2><h2>Keep going</h2>climb #{"word " * 120}"

    checklist = post.seo_checklist
    assert checklist[:focus_in_title]
    assert checklist[:focus_in_first_100]
    assert checklist[:two_headings]
    assert_not checklist[:six_hundred_words]
  end
end
