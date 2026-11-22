# frozen_string_literal: true

require "test_helper"

class BlogHelperTest < ActionView::TestCase
  include BlogHelper

  test "blog_post_body_html sets width and height on embedded images" do
    post = BlogPost.create!(title: "Image post", slug: "image-post", status: "draft")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("fake-image"),
      filename: "inline.png",
      content_type: "image/png"
    )
    blob.update!(metadata: blob.metadata.merge("width" => 640, "height" => 480))

    post.body.attach(blob)
    post.save!
    post.reload

    html = blog_post_body_html(post)

    assert_match(/width="640"/, html)
    assert_match(/height="480"/, html)
  end
end
