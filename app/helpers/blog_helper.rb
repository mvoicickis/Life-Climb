# frozen_string_literal: true

module BlogHelper
  COVER_CARD_WIDTH = 640
  COVER_CARD_HEIGHT = 360
  COVER_HERO_WIDTH = 1_200
  COVER_HERO_HEIGHT = 675
  COVER_OG_WIDTH = 1_200
  COVER_OG_HEIGHT = 630

  def blog_post_cover_tag(post, width:, height:, loading: "lazy", css_class: nil)
    if post.cover_photo.attached?
      variant = post.cover_photo.variant(resize_to_fill: [ width, height ], format: :webp)
      image_tag variant,
                width: width,
                height: height,
                loading: loading,
                alt: "",
                class: css_class,
                decoding: "async"
    else
      tag.div("", class: "#{css_class} is-placeholder", role: "presentation")
    end
  end

  def blog_cover_og_url(post)
    return unless post.cover_photo.attached?

    variant = post.cover_photo.variant(resize_to_fill: [ COVER_OG_WIDTH, COVER_OG_HEIGHT ], format: :jpeg)
    absolute_url(url_for(variant))
  end

  def blog_author_name(post)
    post.author_name.presence || t("blog.author_default")
  end

  def blog_author_initial(post)
    blog_author_name(post).to_s.strip.first&.upcase || "?"
  end

  def blog_published_on(post)
    l((post.published_at || post.created_at).to_date, format: :long)
  end

  def blog_reading_time(post)
    t("blog.min_read", count: post.reading_minutes)
  end

  def blog_card_excerpt(post)
    post.excerpt.presence || post.meta_description.to_s
  end
end
