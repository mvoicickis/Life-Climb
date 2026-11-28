# frozen_string_literal: true

module Admin
  # Development-only in-memory board rows for ?preview=sample (never persisted).
  class DevBoardSamplePreview
    SAMPLES = [
      { status: :todo, kind: :bug, title: "Stats page locks on old calendar month", priority: :urgent,
        owner: :mareks, reporter: :mareks, created_on: Date.new(2026, 11, 27) },
      { status: :needs_check, kind: :bug, title: "Climb together invite shows wrong name", priority: :urgent,
        owner: :karen, reporter: :karen, created_on: Date.new(2026, 11, 22) },
      { status: :needs_check, kind: :feature, title: "Share picture working part", priority: :important,
        owner: :karen, reporter: :karen, created_on: Date.new(2026, 11, 23) },
      { status: :doing, kind: :bug, title: "Memory leak on Render", priority: :urgent,
        owner: :mareks, reporter: :mareks, created_on: Date.new(2026, 11, 25) },
      { status: :doing, kind: :improvement, title: "Desktop layout", priority: :important,
        owner: :karen, reporter: :karen, created_on: Date.new(2026, 11, 24) },
      { status: :done, kind: :check, title: "Export stats missing last week", priority: :important,
        owner: :mareks, reporter: :mareks, created_on: Date.new(2026, 11, 18) },
      { status: :idea, kind: :bug, title: "Mountain trail coach text runs off on small phones",
        priority: :important, owner: :mareks, reporter: :mareks, created_on: Date.new(2026, 11, 21) },
      { status: :idea, kind: :check, title: "Rename Basics to Habits", priority: :nice_to_have,
        owner: :karen, reporter: :karen, created_on: Date.new(2026, 11, 20) }
    ].freeze

    def self.enabled?(preview_param)
      Rails.env.development? && preview_param.to_s == "sample"
    end

    def self.build(users:)
      owners = resolve_owners(users)
      items = SAMPLES.map { |row| build_item(row, owners) }
      grouped = items.group_by(&:status)
      columns = DevBoardItem::COLUMN_STATUSES.index_with { |status| grouped[status] || [] }
      { columns: columns }
    end

    def self.resolve_owners(users)
      list = Array(users).compact
      primary, secondary = list.first(2)
      { mareks: primary || User.new(name: "Mareks"), karen: secondary || primary || User.new(name: "Karen") }
    end

    def self.build_item(row, owners)
      owner = owners.fetch(row[:owner])
      reporter = owners.fetch(row[:reporter])
      DevBoardItem.new(
        title: row[:title],
        kind: row[:kind],
        priority: row[:priority],
        status: row[:status],
        owner: owner,
        reported_by: reporter,
        created_at: row[:created_on].in_time_zone.beginning_of_day
      )
    end

    private_class_method :build_item, :resolve_owners
  end
end
