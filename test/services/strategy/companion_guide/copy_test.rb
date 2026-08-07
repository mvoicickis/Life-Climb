# frozen_string_literal: true

require "test_helper"

class Strategy::CompanionGuide::CopyTest < ActiveSupport::TestCase
  test "ack samples from the i18n pool with prefix" do
    phrases = Strategy::CompanionGuide::Copy.phrases(locale: :en)
    assert_equal 6, phrases.size
    assert_equal 6, phrases.uniq.size

    seen = []
    30.times do
      ack = Strategy::CompanionGuide::Copy.ack(locale: :en)
      assert ack.start_with?(Strategy::CompanionGuide::Copy::PREFIX)
      seen << ack.delete_prefix(Strategy::CompanionGuide::Copy::PREFIX)
    end
    assert_operator (seen.uniq & phrases).size, :>=, 1
  end
end
