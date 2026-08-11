# frozen_string_literal: true

module Patterns
  # Orchestrates pattern detectors with a once-per-day query snapshot.
  # Snapshots store key/data/cta_variant only — copy renders via I18n at read time.
  class Detector
    DETECTORS = [
      Patterns::Detectors::CompletionRate,
      Patterns::Detectors::WeekdayGap
    ].freeze

    def self.call(user:, on: Date.current)
      new(user: user, on: on).call
    end

    def initialize(user:, on: Date.current)
      @user = user
      @on = on
    end

    def call
      snapshot = @user.pattern_snapshots.find_by(computed_on: @on)
      return hydrate(snapshot.findings) if snapshot

      findings = run_detectors
      @user.pattern_snapshots.create!(
        computed_on: @on,
        findings: findings.map(&:to_snapshot_h)
      )
      findings
    end

    private

    def run_detectors
      DETECTORS.filter_map { |detector| detector.call(user: @user, on: @on) }
    end

    def hydrate(rows)
      Array(rows).map { |row| Patterns::Finding.from_snapshot_h(row) }
    end
  end
end
