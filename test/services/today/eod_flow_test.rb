# frozen_string_literal: true

require "test_helper"

class Today::EodFlowTest < ActiveSupport::TestCase
  test "hidden when not ready" do
    session = {}
    assert_equal :hidden, Today::EodFlow.step(session: session, end_of_day_ready: false, day_closed: false)
  end

  test "closed when day ended" do
    session = {}
    assert_equal :closed, Today::EodFlow.step(session: session, end_of_day_ready: false, day_closed: true)
  end

  test "hidden when ready but user has not started day won" do
    session = {}
    assert_equal :hidden, Today::EodFlow.step(session: session, end_of_day_ready: true, day_closed: false)
  end

  test "day won when acknowledged for today" do
    session = { Today::EodFlow::ACK_SESSION_KEY => Date.current.to_s }
    assert_equal :day_won, Today::EodFlow.step(session: session, end_of_day_ready: true, day_closed: false)
  end

  test "reset acknowledge clears session" do
    session = { Today::EodFlow::ACK_SESSION_KEY => Date.current.to_s }
    Today::EodFlow.reset_acknowledge!(session)
    refute Today::EodFlow.acknowledged?(session)
  end
end
