# frozen_string_literal: true

require "test_helper"

class Strategy::ProjectCheckQueueTest < ActiveSupport::TestCase
  test "pending detects queued project id" do
    session = {}
    Strategy::ProjectCheckQueue.enqueue(session: session, project_ids: [ 12, 34 ])

    assert Strategy::ProjectCheckQueue.pending?(session: session, project_id: 12)
    refute Strategy::ProjectCheckQueue.pending?(session: session, project_id: 99)
  end
end
