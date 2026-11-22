# frozen_string_literal: true

class PublicSitemap
  STATIC_ENTRIES = [
    { path: "/", changefreq: "weekly", priority: "1.0" },
    { path: "/about", changefreq: "monthly", priority: "0.6" },
    { path: "/support", changefreq: "monthly", priority: "0.5" },
    { path: "/session/new", changefreq: "monthly", priority: "0.4" },
    { path: "/registration/new", changefreq: "monthly", priority: "0.7" },
    { path: "/blog", changefreq: "weekly", priority: "0.8" }
  ].freeze

  def self.urls
    base = CanonicalHost.base_url

    static = STATIC_ENTRIES.map do |entry|
      build_url(
        loc: "#{base}#{entry[:path]}",
        changefreq: entry[:changefreq],
        priority: entry[:priority]
      )
    end

    posts = BlogPost.published.map do |post|
      build_url(
        loc: "#{base}/blog/#{post.slug}",
        lastmod: (post.updated_at || post.published_at).to_date.iso8601,
        changefreq: "monthly",
        priority: "0.7"
      )
    end

    static + posts
  end

  def self.build_url(loc:, lastmod: nil, changefreq: nil, priority: nil)
    {
      loc: loc,
      lastmod: lastmod,
      changefreq: changefreq,
      priority: priority
    }.compact
  end
  private_class_method :build_url
end
