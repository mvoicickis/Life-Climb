class Feedback < ApplicationRecord
  RATINGS = (1..5).to_a.freeze

  belongs_to :user, optional: true

  validates :body, presence: true, length: { minimum: 2, maximum: 2_000 }
  validates :rating, inclusion: { in: RATINGS }, allow_nil: true
  validates :page_context, length: { maximum: 200 }, allow_nil: true
  validates :app_version, length: { maximum: 7 }, allow_nil: true
  validates :contact_info, length: { maximum: 120 }, allow_nil: true

  before_validation :normalize_fields

  scope :newest_first, -> { order(created_at: :desc) }
  scope :follow_up_ok, -> { where(ok_to_contact: true) }

  def rating_label
    return nil if rating.blank?

    I18n.t("feedback.ratings.#{rating}", default: rating.to_s)
  end

  private

  def normalize_fields
    self.page_context = page_context.to_s.strip.presence&.truncate(200)
    self.app_version = app_version.to_s.strip.presence&.truncate(7)
    self.body = body.to_s.strip.presence
    self.rating = rating.presence&.to_i
    self.rating = nil unless rating.in?(RATINGS)
    self.ok_to_contact = ActiveModel::Type::Boolean.new.cast(ok_to_contact)
    self.contact_info = contact_info.to_s.strip.presence&.truncate(120)
    self.contact_info = nil unless ok_to_contact?
  end
end
