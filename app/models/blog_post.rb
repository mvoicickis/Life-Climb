# frozen_string_literal: true

class BlogPost < ApplicationRecord
  STATUSES = %w[draft published].freeze
  WORDS_PER_MINUTE = 200

  has_rich_text :body
  has_one_attached :cover_photo

  validates :title, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :status, inclusion: { in: STATUSES }

  before_validation :assign_slug_from_title
  before_validation :normalize_slug

  scope :published, lambda {
    where(status: "published")
      .where(published_at: ..Time.current)
      .order(published_at: :desc)
  }

  def reading_minutes
    words = body.to_plain_text.to_s.split.size
    [ (words.to_f / WORDS_PER_MINUTE).ceil, 1 ].max
  end

  def published?
    status == "published" && published_at.present? && published_at <= Time.current
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
end
