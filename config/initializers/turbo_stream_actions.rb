# frozen_string_literal: true

module TurboStreamActionsHelper
  def open_trail_camp(camp_id)
    turbo_stream_action_tag :open_trail_camp, target: "mountain-trail", "camp-id": camp_id
  end

  def open_terrace_sheet(sheet_id:, title:, camp_id: nil)
    turbo_stream_action_tag :open_terrace_sheet,
      target: "mountain-trail",
      "sheet-id": sheet_id,
      "sheet-title": title,
      "camp-id": camp_id
  end
end

Turbo::Streams::TagBuilder.prepend(TurboStreamActionsHelper)
