class Building < ApplicationRecord
  include TextLimits

  belongs_to :user
  belongs_to :step
  has_many :today_actions, -> { order(:position, :id) }, dependent: :destroy
  has_one :finished_product, dependent: :nullify

  validates :title, presence: true, length: { maximum: TITLE_MAX }
  validates :summary, length: { maximum: SUMMARY_MAX }, allow_nil: true

  scope :active, -> { where(status: "active") }
  scope :shipped, -> { where(status: "shipped") }

  def goal
    step.goal
  end

  def dream
    goal.dream
  end

  def focus?
    user.focus_building_id == id
  end
end
