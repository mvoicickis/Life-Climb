# frozen_string_literal: true

module Admin
  # Per-step funnel from user_events — viewed vs completed counts.
  class OnboardingStepFunnel
    ONBOARDING = {
      steps: V2OnboardingsController::STEPS,
      event_prefix: "onboarding",
      label_scope: "admin.onboarding_steps"
    }.freeze

    MOUNTAIN_TOUR = {
      steps: OnboardingMountainTour::STEPS,
      event_prefix: "mountain_tour",
      label_scope: "admin.mountain_tour_steps"
    }.freeze

    StepRow = Data.define(:key, :label, :viewed, :completed, :drop_off_from_previous)

    def self.call(config = ONBOARDING)
      new(config).call
    end

    def initialize(config)
      @steps = config.fetch(:steps)
      @event_prefix = config.fetch(:event_prefix)
      @label_scope = config.fetch(:label_scope)
    end

    def call
      user_ids = User.excluding_privileged.select(:id)
      viewed = counts_for("#{@event_prefix}_step_viewed", user_ids)
      completed = counts_for("#{@event_prefix}_step_completed", user_ids)

      rows = @steps.map.with_index do |key, index|
        previous_completed = index.zero? ? nil : completed[@steps[index - 1]].to_i
        current_completed = completed[key].to_i
        drop_off = previous_completed.nil? ? nil : [ previous_completed - current_completed, 0 ].max

        StepRow.new(
          key: key,
          label: I18n.t("#{@label_scope}.#{key}"),
          viewed: viewed[key].to_i,
          completed: current_completed,
          drop_off_from_previous: drop_off
        )
      end

      { rows: rows }
    end

    private

    def counts_for(event_name, user_ids)
      counts = Hash.new { |hash, key| hash[key] = Set.new }
      UserEvent.where(user_id: user_ids, name: event_name)
               .pluck(:user_id, :properties)
               .each do |user_id, properties|
        step = properties.is_a?(Hash) ? properties["step"] : properties
        step = step["step"] if step.is_a?(Hash)
        counts[step] << user_id if step.present?
      end
      counts.transform_values(&:size)
    end
  end
end
