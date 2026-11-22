# frozen_string_literal: true

class BlogPost < ApplicationRecord
  STATUSES = %w[draft published].freeze
  WORDS_PER_MINUTE = 200
  EXCERPT_LENGTH = 160
  SEO_TITLE_MAX = 60
  META_DESCRIPTION_MAX = 155

  has_rich_text :body
  has_one_attached :cover_photo

  validates :title, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :status, inclusion: { in: STATUSES }
  validates :seo_title, length: { maximum: SEO_TITLE_MAX }, allow_blank: true
  validates :meta_description, length: { maximum: META_DESCRIPTION_MAX }, allow_blank: true

  before_validation :assign_slug_from_title
  before_validation :normalize_slug
  before_validation :assign_excerpt_from_body
  before_validation :assign_seo_defaults

  scope :published, lambda {
    where(status: "published")
      .where(published_at: ..Time.current)
      .order(published_at: :desc)
  }

  def self.related_for(post, limit: 3)
    published.where.not(id: post.id).limit(limit)
  end

  def reading_minutes
    words = body.to_plain_text.to_s.split.size
    [ (words.to_f / WORDS_PER_MINUTE).ceil, 1 ].max
  end

  def published?
    status == "published" && published_at.present? && published_at <= Time.current
  end

  def word_count
    body.to_plain_text.to_s.split(/\s+/).count(&:present?)
  end

  def heading_count
    Nokogiri::HTML.fragment(body.body.to_s).css("h1, h2, h3").size
  end

  def focus_phrase_in_title?
    return false if focus_phrase.blank?

    title.to_s.downcase.include?(focus_phrase.downcase)
  end

  def focus_phrase_in_first_100_words?
    return false if focus_phrase.blank?

    snippet = body.to_plain_text.to_s.split(/\s+/).first(100).join(" ").downcase
    snippet.include?(focus_phrase.downcase)
  end

  def seo_checklist
    {
      focus_in_title: focus_phrase_in_title?,
      focus_in_first_100: focus_phrase_in_first_100_words?,
      two_headings: heading_count >= 2,
      cover_photo: cover_photo.attached?,
      six_hundred_words: word_count >= 600,
      meta_filled: meta_description.present?
    }
  end

  def google_preview_title
    seo_title.presence || title
  end

  private

  def assign_slug_from_title
    return if slug.present?
    return if title.blank?

    self.slug = title
  end

  def normalize_slug
    self.slug = slug.to_s.parameterize.presence
  end

  def assign_excerpt_from_body
    return if excerpt.present?

    plain = body.to_plain_text.to_s.squish
    return if plain.blank?

    self.excerpt = plain.truncate(EXCERPT_LENGTH, omission: "")
  end

  def assign_seo_defaults
    if seo_title.blank? && title.present?
      self.seo_title = title.to_s.truncate(SEO_TITLE_MAX, omission: "")
    end

    if meta_description.blank?
      teaser = excerpt.presence || body.to_plain_text.to_s.squish
      return if teaser.blank?

      self.meta_description = teaser.truncate(META_DESCRIPTION_MAX, omission: "")
    end
  end
end
