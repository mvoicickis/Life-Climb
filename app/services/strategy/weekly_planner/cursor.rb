# frozen_string_literal: true

module Strategy
  module WeeklyPlanner
    # Durable planner cursor inside life_journeys.setup_flags["weekly_planner"].
    # Isolated from companion_guide — merge only this FLAG_KEY.
    class Cursor
      FLAG_KEY = "weekly_planner"
      VERSION = 1

      def self.load(journey)
        flags = (journey.setup_flags.presence || {}).stringify_keys
        raw = flags[FLAG_KEY]
        return nil if raw.blank?

        raw = raw.stringify_keys if raw.respond_to?(:stringify_keys)
        return nil unless raw.is_a?(Hash)

        normalize(raw)
      end

      def self.start!(journey, plan:)
        data = {
          "version" => VERSION,
          "status" => "in_progress",
          "template_id" => "pick_source",
          "plan_id" => plan.id,
          "project_id" => nil,
          "title" => nil,
          "source_practice_task_id" => nil,
          "sitting_count" => nil,
          "selected_dates" => [],
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
        "#{data['template_id']}:#{data['title']}:#{data['sitting_count']}"
      end

      def self.normalize(data)
        h = data.stringify_keys
        dates = Array(h["selected_dates"]).map { |d| d.to_s.presence }.compact
        {
          "version" => (h["version"] || VERSION).to_i,
          "status" => h["status"].to_s.presence || "in_progress",
          "template_id" => h["template_id"].to_s,
          "plan_id" => h["plan_id"].presence&.to_i,
          "project_id" => h["project_id"].presence&.to_i,
          "title" => h["title"].to_s.presence,
          "source_practice_task_id" => h["source_practice_task_id"].presence&.to_i,
          "sitting_count" => h["sitting_count"].presence&.to_i,
          "selected_dates" => dates,
          "answered_key" => h["answered_key"].presence
        }
      end
      private_class_method :normalize
    end
  end
end
