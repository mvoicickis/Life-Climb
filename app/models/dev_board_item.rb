# frozen_string_literal: true

class DevBoardItem < ApplicationRecord
  include TextLimits

  KINDS = %w[bug feature improvement check].freeze
  PRIORITIES = %w[urgent important nice_to_have].freeze
  STATUSES = %w[idea todo doing needs_check done].freeze
  COLUMN_STATUSES = %w[idea todo doing needs_check done].freeze
  REPORTER_NOTE_MAX = 120
  CHECK_NOTE_MAX = 500

  MOVES = {
    "plan_for_week" => %w[idea].freeze,
    "start" => %w[todo].freeze,
    "send_to_check" => %w[doing].freeze,
    "looks_good" => %w[needs_check].freeze,
    "not_yet" => %w[needs_check].freeze
  }.freeze

  KIND_ICONS = {
    "bug" => "\u{1F41E}",
    "feature" => "\u2728",
    "improvement" => "\u{1F527}",
    "check" => "\u{1F440}"
  }.freeze

  belongs_to :owner, class_name: "User"
  belongs_to :reported_by, class_name: "User", optional: true
  belongs_to :work_owner, class_name: "User", optional: true

  enum :kind, { bug: "bug", feature: "feature", improvement: "improvement", check: "check" }, validate: true
  enum :priority, { urgent: "urgent", important: "important", nice_to_have: "nice_to_have" }, validate: true
  enum :status, {
    idea: "idea",
    todo: "todo",
    doing: "doing",
    needs_check: "needs_check",
    done: "done"
  }, validate: true

  validates :title, presence: true, length: { maximum: TITLE_MAX }
  validates :description, length: { maximum: SUMMARY_MAX }, allow_blank: true
  validates :reporter_note, length: { maximum: REPORTER_NOTE_MAX }, allow_blank: true
  validates :check_note, length: { maximum: CHECK_NOTE_MAX }, allow_blank: true

  scope :column_sorted, -> {
    order(
      Arel.sql(
        "CASE priority WHEN 'urgent' THEN 0 WHEN 'important' THEN 1 WHEN 'nice_to_have' THEN 2 ELSE 3 END"
      ),
      created_at: :desc
    )
  }

  def self.other_admin(owner, admins)
    Array(admins).find { |user| user.id != owner.id }
  end

  def move!(to:, actor:, admins:, check_note: nil, column: nil)
    move = to.to_s
    return apply_relocate!(column: column, admins: admins) if move == "relocate"

    unless MOVES.key?(move)
      errors.add(:base, I18n.t("admin.dev_board.moves.invalid"))
      return false
    end

    unless MOVES[move].include?(status)
      errors.add(:base, I18n.t("admin.dev_board.moves.not_allowed"))
      return false
    end

    admin_ids = Array(admins).map(&:id)

    case move
    when "plan_for_week"
      self.status = :todo
    when "start"
      self.status = :doing
    when "send_to_check"
      return false unless apply_send_to_check!(admins)
    when "looks_good"
      apply_mark_done!
    when "not_yet"
      note = check_note.to_s.strip
      if note.blank?
        errors.add(:check_note, I18n.t("admin.dev_board.moves.check_note_required"))
        return false
      end
      if work_owner_id.blank?
        errors.add(:base, I18n.t("admin.dev_board.moves.missing_work_owner"))
        return false
      end
      unless admin_ids.include?(work_owner_id)
        errors.add(:work_owner, I18n.t("admin.dev_board.report.owner_invalid"))
        return false
      end
      self.owner_id = work_owner_id
      self.work_owner_id = nil
      self.status = :doing
      self.check_note = note
    end

    save
  end

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

  private

  def apply_send_to_check!(admins)
    checker = self.class.other_admin(owner, admins)
    if checker.nil?
      errors.add(:base, I18n.t("admin.dev_board.moves.need_second_admin"))
      return false
    end
    self.work_owner_id = owner_id
    self.owner = checker
    self.status = :needs_check
    true
  end

  def apply_mark_done!
    self.status = :done
    self.done_at = Time.current
    self.work_owner_id = nil
    self.check_note = nil
  end

  def apply_relocate!(column:, admins:)
    dest = column.to_s
    unless STATUSES.include?(dest)
      errors.add(:column, I18n.t("admin.dev_board.moves.invalid"))
      return false
    end
    if dest == status
      errors.add(:base, I18n.t("admin.dev_board.moves.not_allowed"))
      return false
    end

    case dest
    when "done"
      apply_mark_done!
    when "needs_check"
      return false unless apply_send_to_check!(admins)
    when "idea", "todo", "doing"
      self.done_at = nil if done?
      self.status = dest
    end

    save
  end
end
