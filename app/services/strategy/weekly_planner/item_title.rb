# frozen_string_literal: true

module Strategy
  module WeeklyPlanner
    # Titles must always be plain strings. Continue submits items[][title] as
    # ActionController::Parameters; calling #to_s on those dumps the whole hash
    # (e.g. {"title" => "Get a job"}) into strategy_goals / daily_todos.
    module ItemTitle
      # Exact Ruby Hash#to_s / Parameters#to_s shape for a single string title.
      DUMP = /\A\{"title"\s*=>\s*"(.*)"\}\z/m

      module_function

      def extract(raw)
        case raw
        when ActionController::Parameters
          extract(raw.to_unsafe_h)
        when Hash
          h = raw.stringify_keys
          extract(h["title"].presence || h["value"])
        else
          text = raw.to_s.strip
          return "" if text.blank?

          if (match = DUMP.match(text))
            unescape(match[1])
          else
            text
          end
        end
      end

      def corrupted?(raw)
        text = raw.to_s.strip
        text.match?(DUMP)
      end

      def unescape(inner)
        inner.gsub('\\"', '"').gsub("\\\\", "\\")
      end
      private_class_method :unescape
    end
  end
end
