# frozen_string_literal: true

require "test_helper"

class Today::EodFlowTest < ActiveSupport::TestCase
  test "step hidden when gate is false" do
    session = {}
    assert_equal :hidden, Today::EodFlow.step(session: session, end_of_day_ready: false, day_closed: false)
  end

  test "step closed when day ended even if gate is false" do
    session = {}
    assert_equal :closed, Today::EodFlow.step(session: session, end_of_day_ready: false, day_closed: true)
  end

  test "step win when ready and not acknowledged" do
    session = {}
    assert_equal :win, Today::EodFlow.step(session: session, end_of_day_ready: true, day_closed: false)
  end

  test "step plan when ready and acknowledged" do
    session = { Today::EodFlow::ACK_SESSION_KEY => Date.current.to_s }
    assert_equal :plan, Today::EodFlow.step(session: session, end_of_day_ready: true, day_closed: false)
  end

  test "reset_acknowledge clears session key" do
    session = { Today::EodFlow::ACK_SESSION_KEY => Date.current.to_s }
    Today::EodFlow.reset_acknowledge!(session)
    refute Today::EodFlow.acknowledged?(session)
  end
end
