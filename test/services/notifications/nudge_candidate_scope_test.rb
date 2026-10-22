# frozen_string_literal: true

require "test_helper"

module Notifications
  class NudgeCandidateScopeTest < ActiveSupport::TestCase
    test "rejects unknown kind" do
      assert_raises(ArgumentError) do
        NudgeCandidateScope.users(kind: :midnight, hours: (7..11))
      end
    end
  end
end
