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
    # 250 words → ceil(250/200) = 2
    post.body = ([ "word" ] * 250).join(" ")

    assert_equal 2, post.reading_minutes
  end
end
