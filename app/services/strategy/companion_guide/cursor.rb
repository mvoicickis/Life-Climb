# frozen_string_literal: true

module Strategy
  module CompanionGuide
    # Durable guide cursor inside life_journeys.setup_flags["companion_guide"].
    # Uses the same merge/update style as the route flag — not mark_layer!.
    class Cursor
      FLAG_KEY = "companion_guide"
      VERSION = 1

      def self.load(journey)
        flags = (journey.setup_flags.presence || {}).stringify_keys
        raw = flags[FLAG_KEY]
        return nil if raw.blank?

        raw = raw.stringify_keys if raw.respond_to?(:stringify_keys)
        return nil unless raw.is_a?(Hash)

        normalize(raw)
      end

      def self.start!(journey, goal:)
        data = {
          "version" => VERSION,
          "status" => "in_progress",
          "template_id" => "create_plan",
          "project_count" => 0,
          "step_count" => 0,
          "goal_id" => goal.id,
          "plan_id" => nil,
          "project_id" => nil,
          "answered_key" => nil
        }
        save!(journey, data)
        data
      end

      def self.save!(journey, data)
        payload = normalize(data)
        flags = (journey.setup_flags.presence || {}).stringify_keys.merge(FLAG_KEY => payload)
        journey.update_columns(setup_flags: flags, updated_at: Time.current)
        journey.setup_flags = flags
        payload
      end

      def self.cursor_key(data)
        data = normalize(data)
        "#{data['template_id']}:#{data['project_count']}:#{data['step_count']}"
      end

      def self.normalize(data)
        h = data.stringify_keys
        {
          "version" => (h["version"] || VERSION).to_i,
          "status" => h["status"].to_s.presence || "in_progress",
          "template_id" => h["template_id"].to_s,
          "project_count" => h["project_count"].to_i,
          "step_count" => h["step_count"].to_i,
          "goal_id" => h["goal_id"].presence&.to_i,
          "plan_id" => h["plan_id"].presence&.to_i,
          "project_id" => h["project_id"].presence&.to_i,
          "answered_key" => h["answered_key"].presence
        }
      end
      private_class_method :normalize
    end
  end
end
