# frozen_string_literal: true

# Area-aware coach copy for Journey climb / create forms.
module AreaCopy
  module_function

  def for(area_key, key, **options)
    area_key = area_key.to_s.presence || "self"
    key = key.to_s
    paths = [
      "area_interview.#{area_key}.#{key}",
      "journeys.sections.#{key}",
      "journeys.climb.#{key}"
    ]
    # Common aliases between climb UI and area_interview keys.
    aliases = {
      "reality" => "present",
      "reality_hint" => "present_hint",
      "present_placeholder" => "present_placeholder",
      "milestone_hint" => "next_placeholder",
      "today_mission_placeholder" => "today_placeholder",
      "today_todo_placeholder" => "today_placeholder",
      "goal_placeholder" => "title_placeholder"
    }
    if (alias_key = aliases[key])
      paths.unshift("area_interview.#{area_key}.#{alias_key}")
    end

    paths.each do |path|
      return I18n.t(path, **options.except(:default)) if I18n.exists?(path)
    end

    options[:default].presence || key.humanize
  end
end
