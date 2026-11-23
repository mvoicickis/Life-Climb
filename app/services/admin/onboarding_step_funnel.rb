# frozen_string_literal: true

module Admin
  # Per-step funnel from user_events — viewed vs completed counts.
  class OnboardingStepFunnel
    ONBOARDING = {
      steps: V2OnboardingsController::STEPS,
      event_prefix: "onboarding",
      label_scope: "admin.onboarding_steps",
      intro_steps: V2OnboardingsController::INTRO_STEPS
    }.freeze

    LANDING = {
      steps: %w[landing_viewed signup_started],
      label_scope: "admin.landing_steps",
      anonymous: true
    }.freeze

    StepRow = Data.define(:key, :label, :viewed, :completed, :skipped, :drop_off_from_previous)

    def self.call(config = ONBOARDING)
      new(config).call
    end

    def initialize(config)
      @steps = config.fetch(:steps)
      @event_prefix = config[:event_prefix]
      @label_scope = config.fetch(:label_scope)
      @anonymous = config[:anonymous] == true
      @intro_steps = Array(config[:intro_steps])
    end

    def call
      counts = @anonymous ? anonymous_counts : user_scoped_counts

      rows = @steps.map.with_index do |key, index|
        previous_completed = index.zero? ? nil : counts[:completed][@steps[index - 1]].to_i
        current_completed = counts[:completed][key].to_i
        drop_off = previous_completed.nil? ? nil : [ previous_completed - current_completed, 0 ].max
        skipped = @intro_steps.include?(key) ? counts[:skipped][key].to_i : nil

        StepRow.new(
          key: key,
          label: I18n.t("#{@label_scope}.#{key}"),
          viewed: counts[:viewed][key].to_i,
          completed: current_completed,
          skipped: skipped,
          drop_off_from_previous: drop_off
        )
      end

      { rows: rows }
    end

    private

    def user_scoped_counts
      user_ids = User.excluding_privileged.select(:id)
      completed_raw = completed_events_by_user_step(user_ids)
      {
        viewed: counts_for("#{@event_prefix}_step_viewed", user_ids),
        completed: completed_raw.transform_values(&:size),
        skipped: skipped_counts(completed_raw)
      }
    end

    def anonymous_counts
      counts = Hash.new(0)
      UserEvent.where(name: @steps).group(:name).count.each do |name, count|
        counts[name] = count
      end

      {
        viewed: counts,
        completed: counts,
        skipped: Hash.new(0)
      }
    end

    def counts_for(event_name, user_ids)
      counts = Hash.new { |hash, key| hash[key] = Set.new }
      UserEvent.where(user_id: user_ids, name: event_name)
               .pluck(:user_id, :properties)
               .each do |user_id, properties|
        step = step_from_properties(properties)
        counts[step] << user_id if step.present?
      end
      counts.transform_values(&:size)
    end

    def completed_events_by_user_step(user_ids)
      counts = Hash.new { |hash, key| hash[key] = Set.new }
      UserEvent.where(user_id: user_ids, name: "#{@event_prefix}_step_completed")
               .pluck(:user_id, :properties)
               .each do |user_id, properties|
        step = step_from_properties(properties)
        counts[step] << user_id if step.present?
      end
      counts
    end

    def skipped_counts(completed_raw)
      user_ids = User.excluding_privileged.select(:id)
      counts = Hash.new { |hash, key| hash[key] = Set.new }
      UserEvent.where(user_id: user_ids, name: "#{@event_prefix}_step_completed")
               .pluck(:user_id, :properties)
               .each do |user_id, properties|
        props = properties.is_a?(Hash) ? properties : {}
        next unless ActiveModel::Type::Boolean.new.cast(props["skipped"])

        step = step_from_properties(properties)
        counts[step] << user_id if step.present?
      end
      counts.transform_values(&:size)
    end

    def step_from_properties(properties)
      step = properties.is_a?(Hash) ? properties["step"] : properties
      step = step["step"] if step.is_a?(Hash)
      step.to_s.presence
    end
  end
end
