# frozen_string_literal: true

module TurboStreamActionsHelper
  def open_trail_camp(camp_id)
    turbo_stream_action_tag :open_trail_camp, target: "mountain-trail", "camp-id": camp_id
  end
end

Turbo::Streams::TagBuilder.prepend(TurboStreamActionsHelper)
