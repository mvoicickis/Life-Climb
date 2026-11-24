# frozen_string_literal: true

class BlogPost < ApplicationRecord
  STATUSES = %w[draft published].freeze
  WORDS_PER_MINUTE = 200
  EXCERPT_LENGTH = 160
  SEO_TITLE_MAX = 60
  META_DESCRIPTION_MAX = 155
  UNTITLED_TITLE = "Untitled draft"
  DRAFT_SLUG_PREFIX = "draft-"

  has_rich_text :body
  has_one_attached :cover_photo

  attr_accessor :sync_slug_from_title

  validates :slug, presence: true, uniqueness: true
  validates :status, inclusion: { in: STATUSES }
  validates :seo_title, length: { maximum: SEO_TITLE_MAX }, allow_blank: true
  validates :meta_description, length: { maximum: META_DESCRIPTION_MAX }, allow_blank: true
  validates :title, presence: true, on: :publish
  validate :title_is_real_for_publish, on: :publish
  validate :slug_is_real_for_publish, on: :publish

  before_validation :apply_draft_defaults, if: :saving_as_draft?
  before_validation :assign_slug_from_title
  before_validation :normalize_slug
  before_validation :assign_excerpt_from_body
  before_validation :assign_seo_defaults
  before_validation :remember_previous_slug, on: :update

  scope :published, lambda {
    where(status: "published")
      .where(published_at: ..Time.current)
      .order(published_at: :desc)
  }

  def self.related_for(post, limit: 3)
    published.where.not(id: post.id).limit(limit)
  end

  def self.find_published_by_current_slug(slug)
    published.find_by(slug: slug)
  end

  def self.find_published_by_legacy_slug(slug)
    return nil if slug.blank?

    published.find_each do |post|
      return post if Array(post.previous_slugs).include?(slug)
    end
    nil
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

  def auto_draft_slug?
    slug.to_s.match?(/\A#{DRAFT_SLUG_PREFIX}[a-z0-9]+\z/i)
  end

  def untitled_draft_title?
    title.to_s.strip.blank? || title.to_s.strip == UNTITLED_TITLE
  end

  def publish_now!
    self.status = "published"
    self.published_at = Time.current if published_at.blank?
    save(context: :publish)
  end

  private

  def saving_as_draft?
    status == "draft" && validation_context != :publish
  end

  def apply_draft_defaults
    self.title = UNTITLED_TITLE if title.to_s.strip.blank?
    assign_unique_draft_slug if slug.blank?
  end

  def assign_unique_draft_slug
    loop do
      candidate = "#{DRAFT_SLUG_PREFIX}#{SecureRandom.alphanumeric(8).downcase}"
      next if BlogPost.exists?(slug: candidate)

      self.slug = candidate
      break
    end
  end

  def assign_slug_from_title
    return if title.blank?
    return if untitled_draft_title?
    return unless slug.blank? || auto_draft_slug? || sync_slug_from_title

    self.slug = title
  end

  def normalize_slug
    self.slug = slug.to_s.parameterize.presence
    assign_unique_draft_slug if slug.blank? && saving_as_draft?
  end

  def title_is_real_for_publish
    return unless untitled_draft_title?

    errors.add(:title, I18n.t("admin.blog_posts.publish_title_required"))
  end

  def slug_is_real_for_publish
    return if slug.present? && !auto_draft_slug?

    errors.add(:title, I18n.t("admin.blog_posts.publish_title_required"))
  end

  def assign_excerpt_from_body
    return if excerpt.present?

    plain = body.to_plain_text.to_s.squish
    return if plain.blank?

    self.excerpt = plain.truncate(EXCERPT_LENGTH, omission: "")
  end

  def remember_previous_slug
    return unless will_save_change_to_attribute?(:slug)
    return unless status == "published"

    old_slug = slug_in_database
    return if old_slug.blank? || old_slug == slug

    list = Array(previous_slugs)
    list << old_slug unless list.include?(old_slug)
    self.previous_slugs = list
  end

  def assign_seo_defaults
    if seo_title.blank? && title.present? && !untitled_draft_title?
      self.seo_title = title.to_s.truncate(SEO_TITLE_MAX, omission: "")
    end

    if meta_description.blank?
      teaser = excerpt.presence || body.to_plain_text.to_s.squish
      return if teaser.blank?

      self.meta_description = teaser.truncate(META_DESCRIPTION_MAX, omission: "")
    end
  end
end