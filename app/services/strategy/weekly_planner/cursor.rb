# frozen_string_literal: true

module Strategy
  module WeeklyPlanner
    # Durable planner cursor inside life_journeys.setup_flags["weekly_planner"].
    # Isolated from companion_guide — merge only this FLAG_KEY.
    class Cursor
      FLAG_KEY = "weekly_planner"
      VERSION = 2

      def self.load(journey)
        flags = (journey.setup_flags.presence || {}).stringify_keys
        raw = flags[FLAG_KEY]
        return nil if raw.blank?

        raw = raw.stringify_keys if raw.respond_to?(:stringify_keys)
        return nil unless raw.is_a?(Hash)

        normalize(raw)
      end

      def self.start!(journey, plan:)
        data = blank_payload(plan_id: plan.id)
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
        titles = Array(data["items"]).map { |i| i["title"].to_s }.join("|")
        "#{data['template_id']}:#{data['item_index']}:#{titles}"
      end

      def self.blank_payload(plan_id: nil, project_id: nil)
        {
          "version" => VERSION,
          "status" => "in_progress",
          "template_id" => "build_items",
          "plan_id" => plan_id,
          "project_id" => project_id,
          "items" => [],
          "item_index" => 0,
          "answered_key" => nil,
          "created_count" => nil,
          "skipped" => []
        }
      end

      def self.legacy?(data)
        h = data.stringify_keys
        version = h["version"].to_i
        return true if version < VERSION
        return true unless h.key?("items")
        return true if %w[pick_source pick_count].include?(h["template_id"].to_s)

        false
      end

      def self.normalize(data)
        h = data.stringify_keys
        items = normalize_items(h["items"])
        skipped = Array(h["skipped"]).filter_map do |row|
          next unless row.respond_to?(:stringify_keys)

          s = row.stringify_keys
          title = s["title"].to_s.presence
          date = s["date"].to_s.presence
          next if title.blank? || date.blank?

          { "title" => title, "date" => date }
        end

        {
          "version" => VERSION,
          "status" => h["status"].to_s.presence || "in_progress",
          "template_id" => h["template_id"].to_s.presence || "build_items",
          "plan_id" => h["plan_id"].presence&.to_i,
          "project_id" => h["project_id"].presence&.to_i,
          "items" => items,
          "item_index" => h["item_index"].to_i,
          "answered_key" => h["answered_key"].presence,
          "created_count" => h["created_count"].presence&.to_i,
          "skipped" => skipped
        }
      end
      private_class_method :normalize

      def self.normalize_items(raw)
        Array(raw).filter_map do |row|
          next unless row.respond_to?(:to_h) || row.is_a?(Hash)

          h = row.respond_to?(:stringify_keys) ? row.stringify_keys : row.to_h.stringify_keys
          title = h["title"].to_s.strip.presence
          next if title.blank?

          dates = Array(h["selected_dates"]).map { |d| d.to_s.presence }.compact
          {
            "title" => title,
            "source_practice_task_id" => h["source_practice_task_id"].presence&.to_i,
            "selected_dates" => dates
          }
        end
      end
      private_class_method :normalize_items
    end
  end
end
