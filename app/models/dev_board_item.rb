# frozen_string_literal: true

class DevBoardItem < ApplicationRecord
  include TextLimits

  KINDS = %w[bug feature improvement check].freeze
  PRIORITIES = %w[urgent important nice_to_have].freeze
  STATUSES = %w[todo doing needs_check done later].freeze
  COLUMN_STATUSES = %w[todo doing needs_check done].freeze
  LATER_STATUS = "later"
  REPORTER_NOTE_MAX = 120

  KIND_ICONS = {
    "bug" => "\u{1F41E}",
    "feature" => "\u2728",
    "improvement" => "\u{1F527}",
    "check" => "\u{1F440}"
  }.freeze

  belongs_to :owner, class_name: "User"
  belongs_to :reported_by, class_name: "User", optional: true

  enum :kind, { bug: "bug", feature: "feature", improvement: "improvement", check: "check" }, validate: true
  enum :priority, { urgent: "urgent", important: "important", nice_to_have: "nice_to_have" }, validate: true
  enum :status, {
    todo: "todo",
    doing: "doing",
    needs_check: "needs_check",
    done: "done",
    later: "later"
  }, validate: true

  validates :title, presence: true, length: { maximum: TITLE_MAX }
  validates :reporter_note, length: { maximum: REPORTER_NOTE_MAX }, allow_blank: true

  scope :column_sorted, -> {
    order(
      Arel.sql(
        "CASE priority WHEN 'urgent' THEN 0 WHEN 'important' THEN 1 WHEN 'nice_to_have' THEN 2 ELSE 3 END"
      ),
      created_at: :desc
    )
  }

  def kind_icon
    KIND_ICONS[kind]
  end

  def priority_label
    I18n.t("admin.dev_board.priorities.#{priority}")
  end

  def status_label
    I18n.t("admin.dev_board.statuses.#{status}")
  end

  def kind_label
    I18n.t("admin.dev_board.kinds.#{kind}")
  end

  def reported_by_label
    if reported_by.present?
      reported_by.display_name
    elsif reporter_note.present?
      reporter_note
    else
      I18n.t("admin.dev_board.reported_internal")
    end
  end
end