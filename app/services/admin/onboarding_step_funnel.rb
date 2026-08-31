# frozen_string_literal: true

module Admin
  # Per-step onboarding funnel from user_events — viewed vs completed counts.
  class OnboardingStepFunnel
    STEPS = V2OnboardingsController::STEPS

    StepRow = Data.define(:key, :label, :viewed, :completed, :drop_off_from_previous)

    def self.call
      new.call
    end

    def call
      user_ids = User.excluding_privileged.select(:id)
      viewed = counts_for("onboarding_step_viewed", user_ids)
      completed = counts_for("onboarding_step_completed", user_ids)

      rows = STEPS.map.with_index do |key, index|
        previous_completed = index.zero? ? nil : completed[STEPS[index - 1]].to_i
        current_completed = completed[key].to_i
        drop_off = previous_completed.nil? ? nil : [ previous_completed - current_completed, 0 ].max

        StepRow.new(
          key: key,
          label: I18n.t("admin.onboarding_steps.#{key}"),
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
