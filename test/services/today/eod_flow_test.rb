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

  test "plan_action_order emphasizes today before 6pm local" do
    user = users(:one)
    user.create_notification_preference!(time_zone: "Europe/Berlin")

    travel_to Time.find_zone!("Europe/Berlin").local(2026, 8, 31, 12, 0, 0) do
      assert_equal %i[today tomorrow], Today::EodFlow.plan_action_order(user: user)
      refute Today::EodFlow.evening_planning?(user: user)
    end
  end

  test "plan_action_order emphasizes tomorrow from 6pm local" do
    user = users(:one)
    user.create_notification_preference!(time_zone: "Europe/Berlin")

    travel_to Time.find_zone!("Europe/Berlin").local(2026, 8, 31, 18, 0, 0) do
      assert_equal %i[tomorrow today], Today::EodFlow.plan_action_order(user: user)
      assert Today::EodFlow.evening_planning?(user: user)
    end
  end
end
